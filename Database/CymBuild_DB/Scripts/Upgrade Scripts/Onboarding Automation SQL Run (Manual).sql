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
    @BusinessUnitGroupGuid UNIQUEIDENTIFIER = '1A80BE64-45DE-4D1D-B5AF-B2C9C195CC79', --'DC65D819-DF10-44B8-B91B-15E831769841',--
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
        @EntityName = N'WorkflowTransitions';

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

    ------------------------------------------------------------
    -- 6. Post-apply scoped verification
    --
    -- Important:
    -- - Product checks are scoped to this staged onboarding run only.
    -- - Existing target/LIVE products are source of truth and are not compared for value mismatches.
    -- - WorkflowTransition FromStatusGuid zero GUID is equivalent to target N/A status.
    ------------------------------------------------------------

    ------------------------------------------------------------
    -- 6.1 Staged products missing from target by Guid or Code
    -- Expected: 0 rows
    ------------------------------------------------------------
    SELECT
        p.RunGuid,
        p.ProductGuid,
        p.Code,
        p.Description
    FROM SMigration.Onboarding_Products AS p
    LEFT JOIN SProd.Products AS tgtByGuid
        ON tgtByGuid.Guid = p.ProductGuid
       AND tgtByGuid.ID > 0
    LEFT JOIN SProd.Products AS tgtByCode
        ON tgtByCode.ID > 0
       AND tgtByCode.RowStatus NOT IN (0,254)
       AND NULLIF(LTRIM(RTRIM(p.Code)), N'') IS NOT NULL
       AND LOWER(LTRIM(RTRIM(tgtByCode.Code))) = LOWER(LTRIM(RTRIM(p.Code)))
    WHERE p.RunGuid = @RunGuid
      AND p.ProductGuid <> '00000000-0000-0000-0000-000000000000'
      AND tgtByGuid.ID IS NULL
      AND tgtByCode.ID IS NULL
    ORDER BY p.Code;

    ------------------------------------------------------------
    -- 6.2 Staged WorkflowTransitions missing from target
    -- Expected: 0 rows
    ------------------------------------------------------------
    SELECT
        wt.RunGuid,
        wt.WorkflowTransitionGuid,
        wf.Name AS WorkflowName,
        fromWs.Name AS FromStatus,
        toWs.Name AS ToStatus,
        wt.Description
    FROM SMigration.Onboarding_WorkflowTransitions AS wt
    INNER JOIN SCore.Workflow AS wf
        ON wf.Guid = wt.WorkflowGuid
    LEFT JOIN SCore.WorkflowStatus AS fromWs
        ON fromWs.Guid = wt.FromStatusGuid
       AND wt.FromStatusGuid <> '00000000-0000-0000-0000-000000000000'
    LEFT JOIN SCore.WorkflowStatus AS toWs
        ON toWs.Guid = wt.ToStatusGuid
       AND wt.ToStatusGuid <> '00000000-0000-0000-0000-000000000000'
    LEFT JOIN SCore.WorkflowTransition AS tgt
        ON tgt.Guid = wt.WorkflowTransitionGuid
       AND tgt.RowStatus NOT IN (0,254)
    WHERE wt.RunGuid = @RunGuid
      AND wt.WorkflowTransitionGuid <> '00000000-0000-0000-0000-000000000000'
      AND tgt.ID IS NULL
    ORDER BY wf.Name, fromWs.Name, toWs.Name;

    ------------------------------------------------------------
    -- 6.3 Staged WorkflowTransition mapping/value mismatches
    -- Expected: 0 rows
    ------------------------------------------------------------
    SELECT
        wt.RunGuid,
        wt.WorkflowTransitionGuid,
        sw.Name AS StagedWorkflowName,
        tw.Name AS TargetWorkflowName,
        CASE
            WHEN wt.FromStatusGuid = '00000000-0000-0000-0000-000000000000'
                THEN N'N/A'
            ELSE sfs.Name
        END AS StagedFromStatus,
        tfs.Name AS TargetFromStatus,
        sts.Name AS StagedToStatus,
        tts.Name AS TargetToStatus,
        wt.Description AS StagedDescription,
        tgt.Description AS TargetDescription
    FROM SMigration.Onboarding_WorkflowTransitions AS wt
    INNER JOIN SCore.WorkflowTransition AS tgt
        ON tgt.Guid = wt.WorkflowTransitionGuid
    INNER JOIN SCore.Workflow AS sw
        ON sw.Guid = wt.WorkflowGuid
    INNER JOIN SCore.Workflow AS tw
        ON tw.ID = tgt.WorkflowID
    LEFT JOIN SCore.WorkflowStatus AS sfs
        ON sfs.Guid = wt.FromStatusGuid
       AND wt.FromStatusGuid <> '00000000-0000-0000-0000-000000000000'
    LEFT JOIN SCore.WorkflowStatus AS tfs
        ON tfs.ID = tgt.FromStatusID
    LEFT JOIN SCore.WorkflowStatus AS sts
        ON sts.Guid = wt.ToStatusGuid
       AND wt.ToStatusGuid <> '00000000-0000-0000-0000-000000000000'
    LEFT JOIN SCore.WorkflowStatus AS tts
        ON tts.ID = tgt.ToStatusID
    WHERE wt.RunGuid = @RunGuid
      AND wt.WorkflowTransitionGuid <> '00000000-0000-0000-0000-000000000000'
      AND tgt.RowStatus NOT IN (0,254)
      AND
      (
          ISNULL(sw.Name, N'') <> ISNULL(tw.Name, N'')
          OR ISNULL
          (
              CASE
                  WHEN wt.FromStatusGuid = '00000000-0000-0000-0000-000000000000'
                      THEN N'N/A'
                  ELSE sfs.Name
              END,
              N''
          ) <> ISNULL(tfs.Name, N'')
          OR ISNULL(sts.Name, N'') <> ISNULL(tts.Name, N'')
          OR ISNULL(wt.Description, N'') <> ISNULL(tgt.Description, N'')
      )
    ORDER BY sw.Name, sfs.Name, sts.Name;

    ------------------------------------------------------------
    -- 6.4 UserPreferences missing after identity import
    -- Expected: 0 rows
    ------------------------------------------------------------
    SELECT
        i.ID AS IdentityID,
        i.Guid AS IdentityGuid,
        i.FullName,
        i.EmailAddress
    FROM SCore.Identities AS i
    LEFT JOIN SCore.UserPreferences AS up
        ON up.ID = i.ID
    WHERE i.RowStatus NOT IN (0,254)
      AND i.ID > 0
      AND up.ID IS NULL
    ORDER BY i.FullName;

    ------------------------------------------------------------
    -- 7. Final run result
    ------------------------------------------------------------
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