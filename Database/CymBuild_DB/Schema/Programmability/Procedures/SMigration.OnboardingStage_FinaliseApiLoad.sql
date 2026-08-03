SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingStage_FinaliseApiLoad]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingStage_FinaliseApiLoad]')
GO

CREATE PROCEDURE [SMigration].[OnboardingStage_FinaliseApiLoad]
    @RunGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    EXEC SMigration.OnboardingRunEntitySelection_ApplyToStage @RunGuid = @RunGuid;

    DECLARE @c INT;

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Groups', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'OrganisationalUnits', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Addresses', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Contacts', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Identities', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'UserGroups', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Workflows WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Workflows', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_WorkflowStatuses WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'WorkflowStatuses', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_WorkflowTransitions WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'WorkflowTransitions', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'WorkflowStatusNotificationGroups', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'JobTypes', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'ActivityTypes', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'MilestoneTypes', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'JobTypeActivityTypes', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'JobTypeMilestoneTemplates', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Products', N'Stage', @c, N'API cross-server staging';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'ProductJobActivities', N'Stage', @c, N'API cross-server staging';

    SELECT
        RunGuid = @RunGuid,
        GroupCount = (SELECT COUNT(*) FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid),
        IdentityCount = (SELECT COUNT(*) FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid),
        UserGroupCount = (SELECT COUNT(*) FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid),
        WorkflowCount = (SELECT COUNT(*) FROM SMigration.Onboarding_Workflows WHERE RunGuid = @RunGuid),
        WorkflowStatusCount = (SELECT COUNT(*) FROM SMigration.Onboarding_WorkflowStatuses WHERE RunGuid = @RunGuid),
        WorkflowTransitionCount = (SELECT COUNT(*) FROM SMigration.Onboarding_WorkflowTransitions WHERE RunGuid = @RunGuid),
        WorkflowNotificationGroupCount = (SELECT COUNT(*) FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid),
        JobTypeCount = (SELECT COUNT(*) FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid),
        ActivityTypeCount = (SELECT COUNT(*) FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid),
        MilestoneTypeCount = (SELECT COUNT(*) FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid),
        ProductCount = (SELECT COUNT(*) FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid),
        JobTypeActivityTypeCount = (SELECT COUNT(*) FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid),
        JobTypeMilestoneTemplateCount = (SELECT COUNT(*) FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid),
        ProductJobActivityCount = (SELECT COUNT(*) FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid);
END
GO