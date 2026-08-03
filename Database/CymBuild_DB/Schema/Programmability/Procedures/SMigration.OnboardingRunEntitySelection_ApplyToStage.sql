SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRunEntitySelection_ApplyToStage]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingRunEntitySelection_ApplyToStage]')
GO

CREATE PROCEDURE [SMigration].[OnboardingRunEntitySelection_ApplyToStage]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RunGuid IS NULL
        THROW 62230, 'RunGuid is required to apply OnBoarding entity selections to staged data.', 1;

    EXEC SMigration.OnboardingRunEntitySelection_Default @RunGuid = @RunGuid;

    DECLARE @Excluded TABLE
    (
        EntityCode NVARCHAR(100) NOT NULL PRIMARY KEY
    );

    INSERT INTO @Excluded
    (
        EntityCode
    )
    SELECT
        sel.EntityCode
    FROM SMigration.Onboarding_RunEntitySelections AS sel
    INNER JOIN SMigration.Onboarding_EntityScope AS scope
        ON scope.Code = sel.EntityCode
       AND scope.RowStatus NOT IN (0,254)
    WHERE sel.RunGuid = @RunGuid
      AND sel.RowStatus NOT IN (0,254)
      AND sel.IsSelected = 0;

    DECLARE @Deleted INT = 0;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'ProductJobActivities')
    BEGIN
        DELETE FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'ProductJobActivities', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'Products')
    BEGIN
        DELETE FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'Products', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'JobTypeMilestoneTemplates')
    BEGIN
        DELETE FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'JobTypeMilestoneTemplates', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'JobTypeActivityTypes')
    BEGIN
        DELETE FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'JobTypeActivityTypes', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'MilestoneTypes')
    BEGIN
        DELETE FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'MilestoneTypes', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'ActivityTypes')
    BEGIN
        DELETE FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'ActivityTypes', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'JobTypes')
    BEGIN
        DELETE FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'JobTypes', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'WorkflowStatusNotificationGroups')
    BEGIN
        DELETE FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'WorkflowStatusNotificationGroups', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'WorkflowTransitions')
    BEGIN
        DELETE FROM SMigration.Onboarding_WorkflowTransitions WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'WorkflowTransitions', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'WorkflowStatuses')
    BEGIN
        DELETE FROM SMigration.Onboarding_WorkflowStatuses WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'WorkflowStatuses', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'Workflows')
    BEGIN
        DELETE FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid;
        DELETE FROM SMigration.Onboarding_WorkflowTransitions WHERE RunGuid = @RunGuid;
        DELETE FROM SMigration.Onboarding_WorkflowStatuses WHERE RunGuid = @RunGuid;
        DELETE FROM SMigration.Onboarding_Workflows WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'Workflows', N'Excluded', @Deleted, N'Deselected workflow scope removed staged workflow rows and dependants.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'UserGroups')
    BEGIN
        DELETE FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'UserGroups', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'Identities')
    BEGIN
        DELETE FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'Identities', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'OrganisationalUnits')
    BEGIN
        DELETE FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'OrganisationalUnits', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'Contacts')
    BEGIN
        DELETE FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'Contacts', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'Addresses')
    BEGIN
        DELETE FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'Addresses', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;

    IF EXISTS (SELECT 1 FROM @Excluded WHERE EntityCode = N'Groups')
    BEGIN
        DELETE FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid;
        SET @Deleted = @@ROWCOUNT;
        IF @Deleted > 0 EXEC SMigration.OnboardingLog_Add @RunGuid, N'Scope', N'Groups', N'Excluded', @Deleted, N'Deselected entity scope removed staged rows.';
    END;
END;
GO