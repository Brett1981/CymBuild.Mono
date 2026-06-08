SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingAuditDashboard]')
GO


/* ================================================================================================
   SMigration.OnboardingAuditDashboard
   Corrected against current SMigration staging schema.

   Output contract consumed by CoreService.OnboardingMigration.cs:
       Result set 1: summary
       Result set 2: staged counts
       Result set 3: validation issues
       Result set 4: execution log

   Notes:
   - Includes dependency entities now present in the current migration schema:
     OrganisationalUnits, Addresses, Contacts.
   ================================================================================================ */
CREATE PROCEDURE [SMigration].[OnboardingAuditDashboard]
    @RunGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH EntityCounts AS
    (
        SELECT N'Groups' AS EntityName, COUNT(*) AS [Count] FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'OrganisationalUnits', COUNT(*) FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'Addresses', COUNT(*) FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'Contacts', COUNT(*) FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'Identities', COUNT(*) FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'UserGroups', COUNT(*) FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'WorkflowStatusNotificationGroups', COUNT(*) FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'JobTypes', COUNT(*) FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'ActivityTypes', COUNT(*) FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'MilestoneTypes', COUNT(*) FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'JobTypeActivityTypes', COUNT(*) FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'JobTypeMilestoneTemplates', COUNT(*) FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'Products', COUNT(*) FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'ProductJobActivities', COUNT(*) FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid
    )
    SELECT
        StagedEntityCount = SUM(CASE WHEN ec.[Count] > 0 THEN 1 ELSE 0 END),
        TotalStagedRows = SUM(ec.[Count]),
        ValidationErrorCount =
            (
                SELECT COUNT(*)
                FROM SMigration.Onboarding_ValidationIssues AS vi
                WHERE vi.RunGuid = @RunGuid
                  AND vi.Severity = N'Error'
            ),
        ValidationWarningCount =
            (
                SELECT COUNT(*)
                FROM SMigration.Onboarding_ValidationIssues AS vi
                WHERE vi.RunGuid = @RunGuid
                  AND vi.Severity = N'Warning'
            ),
        ExecutionLogCount =
            (
                SELECT COUNT(*)
                FROM SMigration.Onboarding_ExecutionLog AS el
                WHERE el.RunGuid = @RunGuid
            ),
        InsertedRowCount =
            (
                SELECT ISNULL(SUM(el.AffectedCount), 0)
                FROM SMigration.Onboarding_ExecutionLog AS el
                WHERE el.RunGuid = @RunGuid
                  AND el.ActionName = N'Insert'
            ),
        UpdatedRowCount =
            (
                SELECT ISNULL(SUM(el.AffectedCount), 0)
                FROM SMigration.Onboarding_ExecutionLog AS el
                WHERE el.RunGuid = @RunGuid
                  AND el.ActionName = N'Update'
            )
    FROM EntityCounts AS ec;

    SELECT
        ec.EntityName,
        ec.[Count]
    FROM
    (
        SELECT N'Groups' AS EntityName, COUNT(*) AS [Count], 10 AS SortOrder FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'OrganisationalUnits', COUNT(*), 20 FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'Addresses', COUNT(*), 30 FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'Contacts', COUNT(*), 40 FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'Identities', COUNT(*), 50 FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'UserGroups', COUNT(*), 60 FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'WorkflowStatusNotificationGroups', COUNT(*), 70 FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'JobTypes', COUNT(*), 80 FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'ActivityTypes', COUNT(*), 90 FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'MilestoneTypes', COUNT(*), 100 FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'JobTypeActivityTypes', COUNT(*), 110 FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'JobTypeMilestoneTemplates', COUNT(*), 120 FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'Products', COUNT(*), 130 FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid
        UNION ALL SELECT N'ProductJobActivities', COUNT(*), 140 FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid
    ) AS ec
    ORDER BY ec.SortOrder;

    SELECT
        vi.EntityName,
        vi.StageTable,
        StageGuid = ISNULL(CONVERT(NVARCHAR(36), vi.StageGuid), N''),
        vi.Severity,
        vi.IssueCode,
        vi.IssueMessage
    FROM SMigration.Onboarding_ValidationIssues AS vi
    WHERE vi.RunGuid = @RunGuid
    ORDER BY
        CASE vi.Severity WHEN N'Error' THEN 1 WHEN N'Warning' THEN 2 ELSE 3 END,
        vi.EntityName,
        vi.IssueCode,
        vi.ID;

    SELECT
        el.StepName,
        el.EntityName,
        el.ActionName,
        el.AffectedCount,
        el.Details,
        LoggedUtc = CONVERT(NVARCHAR(30), el.LoggedUtc, 126)
    FROM SMigration.Onboarding_ExecutionLog AS el
    WHERE el.RunGuid = @RunGuid
    ORDER BY el.ID;
END;

GO