USE [CymBuild_UAT_Test]; -- target database
GO

/* ================================================================================================
   SQL-only onboarding migration harness

   IMPORTANT:
   - This harness must NOT open an outer transaction.
   - SMigration.OnboardingImport_Apply owns its own transaction and rollback.
   - Opening a transaction here causes Msg 3930 if the inner apply fails and tries to log.
   - @PreviewOnly = 1 stages, validates, reports and runs apply preview only.
   - @PreviewOnly = 0 stages, validates, reports, then performs real apply inside the proc transaction.
   ================================================================================================ */
    DBCC CHECKIDENT ('SCore.Groups', RESEED);
    DBCC CHECKIDENT ('SCrm.Addresses', RESEED);
    DBCC CHECKIDENT ('SCrm.Contacts', RESEED);
    DBCC CHECKIDENT ('SCore.OrganisationalUnits', RESEED);
    DBCC CHECKIDENT ('SCore.Identities', RESEED);
    DBCC CHECKIDENT ('SCore.UserGroups', RESEED);
    DBCC CHECKIDENT ('SCore.Workflow', RESEED);
    DBCC CHECKIDENT ('SCore.WorkflowStatusNotificationGroups', RESEED);
    DBCC CHECKIDENT ('SJob.JobTypes', RESEED);
    DBCC CHECKIDENT ('SJob.ActivityTypes', RESEED);
    DBCC CHECKIDENT ('SJob.MilestoneTypes', RESEED);
    DBCC CHECKIDENT ('SJob.JobTypeActivityTypes', RESEED);
    DBCC CHECKIDENT ('SJob.JobTypeMilestoneTemplates', RESEED);
    DBCC CHECKIDENT ('SProd.Products', RESEED);
    DBCC CHECKIDENT ('SJob.ProductJobActivities', RESEED);
    GO

/* ================================================================================================
   Obtain Business Unit Guid
   ================================================================================================

SELECT
    g.Guid AS BusinessUnitGroupGuid,
    g.Code AS GroupCode,
    g.Name AS GroupName,
    ou.Guid AS OrganisationalUnitGuid,
    ou.Name AS OrganisationalUnitName,
    ou.CostCentreCode
FROM SCore.OrganisationalUnits AS ou
INNER JOIN SCore.Groups AS g
    ON g.ID = ou.DefaultSecurityGroupId
WHERE ou.RowStatus NOT IN (0,254)
  AND g.RowStatus NOT IN (0,254)
  AND ou.ID > 0
  AND g.ID > 0
  AND ou.IsDepartment = 1
ORDER BY ou.Name;

*/


/* ================================================================================================
   Check / rerun existing staged run
   ================================================================================================

SELECT
    r.RunGuid,
    r.CreatedUtc,
    r.SourceDatabase,
    r.SourceBusinessUnitGroupGuid,
    r.SourceBusinessUnitOrganisationalUnitGuid,
    r.Notes,
    r.CreatedBy
FROM SMigration.Onboarding_Run AS r
ORDER BY r.CreatedUtc DESC;

DECLARE @ExistingRunGuid UNIQUEIDENTIFIER = 'PUT-EXISTING-RUN-GUID-HERE';

EXEC SMigration.OnboardingValidate
    @RunGuid = @ExistingRunGuid;

EXEC SMigration.OnboardingReport
    @RunGuid = @ExistingRunGuid;

EXEC SMigration.OnboardingAuditDashboard
    @RunGuid = @ExistingRunGuid;

EXEC SMigration.OnboardingImport_Apply
    @RunGuid = @ExistingRunGuid,
    @AllowWarnings = 1,
    @PreviewOnly = 1;

*/


SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @SourceDatabase SYSNAME = N'CymBuild_UAT',
    @BusinessUnitGroupGuid UNIQUEIDENTIFIER = '1A80BE64-45DE-4D1D-B5AF-B2C9C195CC79',
    @RunGuid UNIQUEIDENTIFIER = NEWID(),
    @AllowWarnings BIT = 1,
    @PreviewOnly BIT = 0; -- 1 = preview only, 0 = real apply

BEGIN TRY

    ------------------------------------------------------------
    -- 1. Stage source data into SMigration tables
    ------------------------------------------------------------
    EXEC SMigration.OnboardingStage_LoadFromSource
        @SourceDatabase = @SourceDatabase,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        @RunGuid = @RunGuid,
        @Notes = N'SQL-only onboarding migration run';

    SELECT
        @RunGuid AS RunGuid,
        @SourceDatabase AS SourceDatabase,
        @BusinessUnitGroupGuid AS BusinessUnitGroupGuid,
        @PreviewOnly AS PreviewOnly;

    ------------------------------------------------------------
    -- 2. Validate staged data
    ------------------------------------------------------------
    EXEC SMigration.OnboardingValidate
        @RunGuid = @RunGuid;

    ------------------------------------------------------------
    -- 3. Review report, audit dashboard and targeted diffs
    ------------------------------------------------------------
    EXEC SMigration.OnboardingReport
        @RunGuid = @RunGuid;

    EXEC SMigration.OnboardingAuditDashboard
        @RunGuid = @RunGuid;

    EXEC SMigration.OnboardingDiff_Report
        @RunGuid = @RunGuid,
        @EntityName = N'Groups';

    EXEC SMigration.OnboardingDiff_Report
        @RunGuid = @RunGuid,
        @EntityName = N'Identities';

    EXEC SMigration.OnboardingDiff_Report
        @RunGuid = @RunGuid,
        @EntityName = N'JobTypes';

    EXEC SMigration.OnboardingDiff_Report
        @RunGuid = @RunGuid,
        @EntityName = N'Products';

    ------------------------------------------------------------
    -- 4. Apply
    --
    -- Do not wrap this in BEGIN TRAN here.
    -- SMigration.OnboardingImport_Apply owns rollback safety.
    ------------------------------------------------------------
    EXEC SMigration.OnboardingImport_Apply
        @RunGuid = @RunGuid,
        @AllowWarnings = @AllowWarnings,
        @PreviewOnly = @PreviewOnly;

    ------------------------------------------------------------
    -- 5. Post-apply audit
    ------------------------------------------------------------
    EXEC SMigration.OnboardingAuditDashboard
        @RunGuid = @RunGuid;

    SELECT
        @RunGuid AS RunGuid,
        @PreviewOnly AS PreviewOnly,
        CASE
            WHEN @PreviewOnly = 1 THEN N'Preview completed. No apply changes were made.'
            ELSE N'Apply completed successfully.'
        END AS ResultMessage;

END TRY
BEGIN CATCH

    ------------------------------------------------------------
    -- Safety rollback only if a transaction is still open.
    -- Normally the apply proc will already have rolled back its own transaction.
    ------------------------------------------------------------
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRAN;
    END;

    SELECT
        @RunGuid AS RunGuid,
        @SourceDatabase AS SourceDatabase,
        @BusinessUnitGroupGuid AS BusinessUnitGroupGuid,
        @PreviewOnly AS PreviewOnly,
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_SEVERITY() AS ErrorSeverity,
        ERROR_STATE() AS ErrorState,
        ERROR_LINE() AS ErrorLine,
        ERROR_PROCEDURE() AS ErrorProcedure,
        ERROR_MESSAGE() AS ErrorMessage;

    THROW;

END CATCH;
GO




