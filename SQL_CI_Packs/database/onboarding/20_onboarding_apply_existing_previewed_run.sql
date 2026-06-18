/* ================================================================================================
   CymBuild Onboarding Migration - Apply existing previewed run

   Required sqlcmd variables:
   - RunGuid
   - AllowWarnings

   Behaviour:
   - Re-validates the exact staged run.
   - Applies using SMigration.OnboardingImport_Apply @PreviewOnly = 0.
   - Import proc owns its transaction and rollback safety.
   - Runs post-apply audit/report.
   ================================================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @RunGuid UNIQUEIDENTIFIER = '$(RunGuid)',
    @AllowWarnings BIT = CONVERT(BIT, '$(AllowWarnings)');

BEGIN TRY
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
        THROW 60000, N'Onboarding apply validation failed. Resolve errors before apply.', 1;
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
        THROW 60000, N'Onboarding apply contains warnings and AllowWarnings = 0.', 1;
    END;

    EXEC SMigration.OnboardingImport_Apply
        @RunGuid = @RunGuid,
        @AllowWarnings = @AllowWarnings,
        @PreviewOnly = 0;

    EXEC SMigration.OnboardingAuditDashboard
        @RunGuid = @RunGuid;

    EXEC SMigration.OnboardingReport
        @RunGuid = @RunGuid;

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
        PreviewOnly = CONVERT(BIT, 0),
        ErrorNumber = ERROR_NUMBER(),
        ErrorSeverity = ERROR_SEVERITY(),
        ErrorState = ERROR_STATE(),
        ErrorLine = ERROR_LINE(),
        ErrorProcedure = ERROR_PROCEDURE(),
        ErrorMessage = ERROR_MESSAGE();

    THROW;
END CATCH;
GO
