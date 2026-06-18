/* ================================================================================================
   CymBuild Onboarding Migration - Stage / Validate / Preview

   Required sqlcmd variables:
   - SourceDatabase
   - BusinessUnitGroupGuid
   - AllowWarnings

   Example:
   sqlcmd -S <server> -d <target_db> -b -i 10_onboarding_stage_validate_preview.sql ^
     -v SourceDatabase="CymBuild_UAT" BusinessUnitGroupGuid="1A80..." AllowWarnings="1"

   Behaviour:
   - Creates a new RunGuid.
   - Stages source data.
   - Validates staged data.
   - Produces report/audit/diff output.
   - Calls SMigration.OnboardingImport_Apply with @PreviewOnly = 1.
   - Emits CI_RUN_GUID=<guid> for pipeline artifact capture.
   ================================================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @SourceDatabase SYSNAME = N'$(SourceDatabase)',
    @BusinessUnitGroupGuid UNIQUEIDENTIFIER = '$(BusinessUnitGroupGuid)',
    @RunGuid UNIQUEIDENTIFIER = NEWID(),
    @AllowWarnings BIT = CONVERT(BIT, '$(AllowWarnings)'),
    @PreviewOnly BIT = 1;

BEGIN TRY
    EXEC SMigration.OnboardingStage_LoadFromSource
        @SourceDatabase = @SourceDatabase,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        @RunGuid = @RunGuid,
        @Notes = N'CI onboarding migration preview';

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
        THROW 60000, N'Onboarding preview validation failed. Resolve errors before apply.', 1;
    END;

    IF @AllowWarnings = 0
       AND EXISTS
       (
           SELECT 1
           FROM SMigration.Onboarding_ValidationIssues
           WHERE RunGuid = @RunGuid
             AND Severity = N'Warning'
       )
    BEGIN
        EXEC SMigration.OnboardingAuditDashboard @RunGuid = @RunGuid;
        THROW 60000, N'Onboarding preview contains warnings and AllowWarnings = 0.', 1;
    END;

    EXEC SMigration.OnboardingReport @RunGuid = @RunGuid;
    EXEC SMigration.OnboardingAuditDashboard @RunGuid = @RunGuid;

    EXEC SMigration.OnboardingDiff_Report @RunGuid = @RunGuid, @EntityName = N'Groups';
    EXEC SMigration.OnboardingDiff_Report @RunGuid = @RunGuid, @EntityName = N'Identities';
    EXEC SMigration.OnboardingDiff_Report @RunGuid = @RunGuid, @EntityName = N'JobTypes';
    EXEC SMigration.OnboardingDiff_Report @RunGuid = @RunGuid, @EntityName = N'Products';

    EXEC SMigration.OnboardingImport_Apply
        @RunGuid = @RunGuid,
        @AllowWarnings = @AllowWarnings,
        @PreviewOnly = 1;

    SELECT
        RunGuid = @RunGuid,
        SourceDatabase = @SourceDatabase,
        BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        PreviewOnly = @PreviewOnly,
        ResultMessage = N'Preview completed. No apply changes were made.';
END TRY
BEGIN CATCH
    SELECT
        RunGuid = @RunGuid,
        SourceDatabase = @SourceDatabase,
        BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        PreviewOnly = @PreviewOnly,
        ErrorNumber = ERROR_NUMBER(),
        ErrorSeverity = ERROR_SEVERITY(),
        ErrorState = ERROR_STATE(),
        ErrorLine = ERROR_LINE(),
        ErrorProcedure = ERROR_PROCEDURE(),
        ErrorMessage = ERROR_MESSAGE();

    THROW;
END CATCH;
GO
