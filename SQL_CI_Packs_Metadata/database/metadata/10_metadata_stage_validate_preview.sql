/* ================================================================================================
   CymBuild Metadata Migration - Stage / Validate / Preview

   Required sqlcmd variables:
   - SourceEnvironment
   - TargetEnvironment
   - SourceServerName
   - SourceDatabaseName
   - TargetServerName
   - TargetDatabaseName

   Optional sqlcmd variables:
   - AllowUpdates: 1 allows non-zero Insert/Update diff counts in preview. 0 fails on any diff.
   - RequireNoValidationIssues: 1 fails on Fail/Warn validation issues. 0 fails only on Fail.

   Notes:
   - This SQL-only runner uses SMigration.MetadataStage_Run. It requires the target SQL session to
     be able to reference the source database using the SourceDatabaseName supplied to MetadataRun_Create.
     For cross-server without linked server, stage through CymBuild API/UI two-connection flow and use
     20_metadata_apply_existing_validated_run.sql for the approved RunGuid.
   ================================================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @RunGuid UNIQUEIDENTIFIER,
    @SourceEnvironment NVARCHAR(20) = N'$(SourceEnvironment)',
    @TargetEnvironment NVARCHAR(20) = N'$(TargetEnvironment)',
    @SourceServerName NVARCHAR(255) = N'$(SourceServerName)',
    @SourceDatabaseName NVARCHAR(255) = N'$(SourceDatabaseName)',
    @TargetServerName NVARCHAR(255) = N'$(TargetServerName)',
    @TargetDatabaseName NVARCHAR(255) = N'$(TargetDatabaseName)',
    @AllowUpdates BIT = CONVERT(BIT, '$(AllowUpdates)'),
    @RequireNoValidationIssues BIT = CONVERT(BIT, '$(RequireNoValidationIssues)');

BEGIN TRY
    EXEC SMigration.MetadataRegistry_Seed;

    EXEC SMigration.MetadataRun_Create
        @SourceEnvironment = @SourceEnvironment,
        @TargetEnvironment = @TargetEnvironment,
        @SourceServerName = @SourceServerName,
        @SourceDatabaseName = @SourceDatabaseName,
        @TargetServerName = @TargetServerName,
        @TargetDatabaseName = @TargetDatabaseName,
        @IsValidateOnly = 1,
        @RunGuid = @RunGuid OUTPUT;

    PRINT N'CI_RUN_GUID=' + CONVERT(NVARCHAR(36), @RunGuid);

    EXEC SMigration.MetadataStage_Run
        @RunGuid = @RunGuid;

    EXEC SMigration.MetadataValidate_Run
        @RunGuid = @RunGuid;

    EXEC SMigration.MetadataApplyIdentityMap_Build
        @RunGuid = @RunGuid;

    EXEC SMigration.MetadataRun_Get
        @RunGuid = @RunGuid;

    SELECT
        tr.SchemaName,
        tr.TableName,
        sr.DifferenceType,
        COUNT_BIG(1) AS RowCount
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
    GROUP BY tr.SchemaName, tr.TableName, sr.DifferenceType
    ORDER BY tr.SchemaName, tr.TableName, sr.DifferenceType;

    IF EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_ValidationIssues AS vi
        WHERE vi.RunGuid = @RunGuid
          AND vi.RowStatus NOT IN (0,254)
          AND vi.Severity = N'Fail'
    )
    BEGIN
        THROW 61000, N'Metadata validation failed. Resolve Fail issues before apply.', 1;
    END;

    IF @RequireNoValidationIssues = 1
       AND EXISTS
       (
           SELECT 1
           FROM SMigration.Metadata_ValidationIssues AS vi
           WHERE vi.RunGuid = @RunGuid
             AND vi.RowStatus NOT IN (0,254)
             AND vi.Severity IN (N'Warn', N'Warning')
       )
    BEGIN
        THROW 61001, N'Metadata validation contains warnings and RequireNoValidationIssues = 1.', 1;
    END;

    IF @AllowUpdates = 0
       AND EXISTS
       (
           SELECT 1
           FROM SMigration.Metadata_StagedRows AS sr
           WHERE sr.RunGuid = @RunGuid
             AND sr.RowStatus NOT IN (0,254)
             AND sr.DifferenceType IN (N'Insert', N'Update')
       )
    BEGIN
        THROW 61002, N'Metadata preview contains Insert/Update differences and AllowUpdates = 0.', 1;
    END;

    SELECT
        RunGuid = @RunGuid,
        SourceEnvironment = @SourceEnvironment,
        TargetEnvironment = @TargetEnvironment,
        PreviewOnly = CONVERT(BIT, 1),
        ResultMessage = N'Metadata preview completed. No apply changes were made.';
END TRY
BEGIN CATCH
    SELECT
        RunGuid = @RunGuid,
        SourceEnvironment = @SourceEnvironment,
        TargetEnvironment = @TargetEnvironment,
        ErrorNumber = ERROR_NUMBER(),
        ErrorSeverity = ERROR_SEVERITY(),
        ErrorState = ERROR_STATE(),
        ErrorLine = ERROR_LINE(),
        ErrorProcedure = ERROR_PROCEDURE(),
        ErrorMessage = ERROR_MESSAGE();

    THROW;
END CATCH;
GO
