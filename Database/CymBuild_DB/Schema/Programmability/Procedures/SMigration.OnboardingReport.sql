SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingReport]')
GO


/* ================================================================================================
   Report
   ================================================================================================ */
PRINT (N'Create procedure [SMigration].[OnboardingReport]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingReport]')
GO

/* ================================================================================================
   Report
   ================================================================================================ */
CREATE PROCEDURE [SMigration].[OnboardingReport]
    @RunGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.RunGuid,
        r.CreatedUtc,
        r.SourceServerName,
        r.SourceDatabase,
        r.TargetServerName,
        r.TargetDatabaseName,
        r.SourceBusinessUnitGroupGuid,
        r.SourceBusinessUnitOrganisationalUnitGuid,
        r.Notes,
        r.CreatedBy
    FROM SMigration.Onboarding_Run AS r
    WHERE r.RunGuid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    SELECT N'Groups' AS EntityName, COUNT(*) AS StagedCount FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'OrganisationalUnits', COUNT(*) FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'Addresses', COUNT(*) FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'Contacts', COUNT(*) FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'Identities', COUNT(*) FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'UserGroups', COUNT(*) FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'Workflows', COUNT(*) FROM SMigration.Onboarding_Workflows WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'WorkflowStatuses', COUNT(*) FROM SMigration.Onboarding_WorkflowStatuses WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'WorkflowTransitions', COUNT(*) FROM SMigration.Onboarding_WorkflowTransitions WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'WorkflowStatusNotificationGroups', COUNT(*) FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'JobTypes', COUNT(*) FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'ActivityTypes', COUNT(*) FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'MilestoneTypes', COUNT(*) FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'JobTypeActivityTypes', COUNT(*) FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'JobTypeMilestoneTemplates', COUNT(*) FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'Products', COUNT(*) FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'ProductJobActivities', COUNT(*) FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid;

    SELECT
        vi.ID,
        vi.RunGuid,
        vi.EntityName,
        vi.StageTable,
        vi.StageGuid,
        vi.Severity,
        vi.IssueCode,
        vi.IssueMessage,
        vi.CreatedUtc
    FROM SMigration.Onboarding_ValidationIssues AS vi
    WHERE vi.RunGuid = @RunGuid
    ORDER BY vi.ID;

    SELECT
        el.ID,
        el.RunGuid,
        el.StepName,
        el.EntityName,
        el.ActionName,
        el.AffectedCount,
        el.Details,
        el.LoggedUtc
    FROM SMigration.Onboarding_ExecutionLog AS el
    WHERE el.RunGuid = @RunGuid
    ORDER BY el.ID;
END

GO