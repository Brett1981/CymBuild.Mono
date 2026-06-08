SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingStage_Reset]')
GO


/* ================================================================================================
   Reset
   ================================================================================================ */
CREATE PROCEDURE [SMigration].[OnboardingStage_Reset]
    @RunGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_ExecutionLog WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_WorkflowTransitions WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Run WHERE RunGuid = @RunGuid;
END

GO