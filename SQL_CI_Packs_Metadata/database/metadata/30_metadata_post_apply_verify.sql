/* ================================================================================================
   CymBuild Metadata Migration - Post-apply verify

   Required sqlcmd variables:
   - SourceEnvironment
   - TargetEnvironment
   - SourceServerName
   - SourceDatabaseName
   - TargetServerName
   - TargetDatabaseName
   - RequireNoDiffs

   Behaviour:
   - Creates a fresh validation-only run.
   - Stages + validates.
   - Fails when RequireNoDiffs = 1 and any Insert/Update remains.
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
    @RequireNoDiffs BIT = CONVERT(BIT, '$(RequireNoDiffs)');

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

    PRINT N'CI_VERIFY_RUN_GUID=' + CONVERT(NVARCHAR(36), @RunGuid);

    EXEC SMigration.MetadataStage_Run @RunGuid = @RunGuid;
    EXEC SMigration.MetadataValidate_Run @RunGuid = @RunGuid;
    EXEC SMigration.MetadataApplyIdentityMap_Build @RunGuid = @RunGuid;

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
        EXEC SMigration.MetadataRun_Get @RunGuid = @RunGuid;
        THROW 61030, N'Metadata post-apply verify has validation failures.', 1;
    END;

    IF @RequireNoDiffs = 1
       AND EXISTS
       (
           SELECT 1
           FROM SMigration.Metadata_StagedRows AS sr
           WHERE sr.RunGuid = @RunGuid
             AND sr.RowStatus NOT IN (0,254)
             AND sr.DifferenceType IN (N'Insert', N'Update')
       )
    BEGIN
        EXEC SMigration.MetadataRun_Get @RunGuid = @RunGuid;
        THROW 61031, N'Metadata post-apply verify found remaining Insert/Update differences.', 1;
    END;

    SELECT
        VerifyRunGuid = @RunGuid,
        RequireNoDiffs = @RequireNoDiffs,
        ResultMessage = N'Metadata post-apply verification completed.';
END TRY
BEGIN CATCH
    SELECT
        VerifyRunGuid = @RunGuid,
        ErrorNumber = ERROR_NUMBER(),
        ErrorSeverity = ERROR_SEVERITY(),
        ErrorState = ERROR_STATE(),
        ErrorLine = ERROR_LINE(),
        ErrorProcedure = ERROR_PROCEDURE(),
        ErrorMessage = ERROR_MESSAGE();

    THROW;
END CATCH;
GO
