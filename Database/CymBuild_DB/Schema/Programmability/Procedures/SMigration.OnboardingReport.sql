SET QUOTED_IDENTIFIER, ANSI_NULLS ON
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

    SELECT * FROM SMigration.Onboarding_Run WHERE RunGuid = @RunGuid;

    SELECT N'Groups' AS EntityName, COUNT(*) AS StagedCount FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid
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
    UNION ALL SELECT N'ProductJobActivities', COUNT(*) FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid;

    SELECT Severity, COUNT(*) AS IssueCount
    FROM SMigration.Onboarding_ValidationIssues
    WHERE RunGuid = @RunGuid
    GROUP BY Severity;

    SELECT * FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid ORDER BY ID;
    SELECT * FROM SMigration.Onboarding_ExecutionLog WHERE RunGuid = @RunGuid ORDER BY ID;
END

GO