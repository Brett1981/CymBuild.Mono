SET QUOTED_IDENTIFIER, ANSI_NULLS ON;
GO

/* ================================================================================================
   CymBuild OnBoarding R3 F3
   Ensure SMigration.OnboardingStage_Reset clears workflow stage rows for repeat staging of the same run.
   This is deployment-safe and non-destructive outside the selected run being restaged.
   ================================================================================================ */
CREATE OR ALTER PROCEDURE [SMigration].[OnboardingStage_Reset]
    @RunGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_ExecutionLog WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Onboarding_WorkflowTransitions WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Workflows WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid;
END;
GO
