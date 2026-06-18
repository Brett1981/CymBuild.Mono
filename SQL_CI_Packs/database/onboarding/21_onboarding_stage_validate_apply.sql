/* ================================================================================================
   CymBuild Onboarding Migration - Stage / Validate / Apply in one controlled run

   Required sqlcmd variables:
   - SourceDatabase
   - BusinessUnitGroupGuid
   - AllowWarnings

   Recommended use:
   - DEV/QA controlled runs.
   - For UAT/LIVE prefer 10_preview followed by 20_apply_existing_previewed_run using approved RunGuid.
   ================================================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @SourceDatabase SYSNAME = N'$(SourceDatabase)',
    @BusinessUnitGroupGuid UNIQUEIDENTIFIER = '$(BusinessUnitGroupGuid)',
    @RunGuid UNIQUEIDENTIFIER = NEWID(),
    @AllowWarnings BIT = CONVERT(BIT, '$(AllowWarnings)');

BEGIN TRY
    EXEC SMigration.OnboardingStage_LoadFromSource
        @SourceDatabase = @SourceDatabase,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        @RunGuid = @RunGuid,
        @Notes = N'CI onboarding migration apply';

    PRINT N'CI_RUN_GUID=' + CONVERT(NVARCHAR(36), @RunGuid);

    EXEC SMigration.OnboardingValidate
        @RunGuid = @RunGuid;

    IF EXISTS
    (
        SELECT 1
        FROM SMigration.Onboarding_ValidationIssues
        WHERE RunGuid = @RunGuid
          AND Severity = N'Error'
    )
    BEGIN
        EXEC SMigration.OnboardingAuditDashboard @RunGuid = @RunGuid;
        THROW 60000, N'Onboarding validation failed. Resolve errors before import.', 1;
    END;

    EXEC SMigration.OnboardingImport_Apply
        @RunGuid = @RunGuid,
        @AllowWarnings = @AllowWarnings,
        @PreviewOnly = 0;

    EXEC SMigration.OnboardingAuditDashboard @RunGuid = @RunGuid;
    EXEC SMigration.OnboardingReport @RunGuid = @RunGuid;

    SELECT
        RunGuid = @RunGuid,
        PreviewOnly = CONVERT(BIT, 0),
        ResultMessage = N'Apply completed successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRAN;
    END;

    SELECT
        RunGuid = @RunGuid,
        SourceDatabase = @SourceDatabase,
        BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        ErrorNumber = ERROR_NUMBER(),
        ErrorSeverity = ERROR_SEVERITY(),
        ErrorState = ERROR_STATE(),
        ErrorLine = ERROR_LINE(),
        ErrorProcedure = ERROR_PROCEDURE(),
        ErrorMessage = ERROR_MESSAGE();

    THROW;
END CATCH;
GO
