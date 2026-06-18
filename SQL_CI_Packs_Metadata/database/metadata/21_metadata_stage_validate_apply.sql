/* ================================================================================================
   CymBuild Metadata Migration - Stage / Validate / Apply in one controlled run

   Required sqlcmd variables:
   - SourceEnvironment
   - TargetEnvironment
   - SourceServerName
   - SourceDatabaseName
   - TargetServerName
   - TargetDatabaseName
   - ForceApply

   Recommended use:
   - DEV / controlled QA only.
   - For UAT/LIVE prefer 10 preview followed by approved 20 apply existing RunGuid.
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
    @ForceApply BIT = CONVERT(BIT, '$(ForceApply)');

BEGIN TRY
    EXEC SMigration.MetadataRegistry_Seed;

    EXEC SMigration.MetadataRun_Create
        @SourceEnvironment = @SourceEnvironment,
        @TargetEnvironment = @TargetEnvironment,
        @SourceServerName = @SourceServerName,
        @SourceDatabaseName = @SourceDatabaseName,
        @TargetServerName = @TargetServerName,
        @TargetDatabaseName = @TargetDatabaseName,
        @IsValidateOnly = 0,
        @RunGuid = @RunGuid OUTPUT;

    PRINT N'CI_RUN_GUID=' + CONVERT(NVARCHAR(36), @RunGuid);

    EXEC SMigration.MetadataStage_Run @RunGuid = @RunGuid;
    EXEC SMigration.MetadataValidate_Run @RunGuid = @RunGuid;

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
        THROW 61020, N'Metadata validation failed. Resolve Fail issues before apply.', 1;
    END;

    EXEC SMigration.MetadataApplyIdentityMap_Build @RunGuid = @RunGuid;
    EXEC SMigration.MetadataApply_Run @RunGuid = @RunGuid, @ForceApply = @ForceApply;
    EXEC SMigration.MetadataRun_Get @RunGuid = @RunGuid;

    SELECT
        RunGuid = @RunGuid,
        SourceEnvironment = @SourceEnvironment,
        TargetEnvironment = @TargetEnvironment,
        ForceApply = @ForceApply,
        ResultMessage = N'Metadata stage/validate/apply completed successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRAN;
    END;

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
