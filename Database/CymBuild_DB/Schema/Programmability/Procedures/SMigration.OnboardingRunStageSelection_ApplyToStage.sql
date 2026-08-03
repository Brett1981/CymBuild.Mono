SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRunStageSelection_ApplyToStage]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRunStageSelection_ApplyToStage]')
GO

CREATE PROCEDURE [SMigration].[OnboardingRunStageSelection_ApplyToStage]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunGuid IS NULL
        THROW 62420, 'RunGuid is required to apply OnBoarding row selections to staging.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Onboarding_RunStageSelections AS selection
        WHERE selection.RunGuid = @RunGuid
          AND selection.RowStatus NOT IN (0,254)
    )
    BEGIN
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Selection', N'All', N'AllRows', 0, N'No row-level migration selection exists; all staged rows remain eligible for apply.';
        RETURN;
    END;

    DECLARE @DeletedCount INT = 0;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'ProductJobActivities' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_ProductJobActivities AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'ProductJobActivities'
                AND selection.RowGuid = targetRows.ProductJobActivityGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'JobTypeMilestoneTemplates' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_JobTypeMilestoneTemplates AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'JobTypeMilestoneTemplates'
                AND selection.RowGuid = targetRows.JobTypeMilestoneTemplateGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'JobTypeActivityTypes' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_JobTypeActivityTypes AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'JobTypeActivityTypes'
                AND selection.RowGuid = targetRows.JobTypeActivityTypeGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'UserGroups' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_UserGroups AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'UserGroups'
                AND selection.RowGuid = targetRows.UserGroupGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'WorkflowTransitions' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_WorkflowTransitions AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'WorkflowTransitions'
                AND selection.RowGuid = targetRows.WorkflowTransitionGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;


    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'WorkflowStatuses' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_WorkflowStatuses AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'WorkflowStatuses'
                AND selection.RowGuid = targetRows.WorkflowStatusGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'WorkflowStatusNotificationGroups' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_WorkflowStatusNotificationGroups AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'WorkflowStatusNotificationGroups'
                AND selection.RowGuid = targetRows.WorkflowNotificationGroupGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'Workflows' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_Workflows AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'Workflows'
                AND selection.RowGuid = targetRows.WorkflowGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'ActivityTypes' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_ActivityTypes AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'ActivityTypes'
                AND selection.RowGuid = targetRows.ActivityTypeGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'MilestoneTypes' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_MilestoneTypes AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'MilestoneTypes'
                AND selection.RowGuid = targetRows.MilestoneTypeGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'Products' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_Products AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'Products'
                AND selection.RowGuid = targetRows.ProductGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'JobTypes' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_JobTypes AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'JobTypes'
                AND selection.RowGuid = targetRows.JobTypeGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'Identities' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_Identities AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'Identities'
                AND selection.RowGuid = targetRows.IdentityGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'OrganisationalUnits' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        ;WITH RequiredOrganisationalUnits AS
        (
            SELECT
                targetRows.OrganisationalUnitGuid,
                targetRows.ParentOrganisationalUnitGuid
            FROM SMigration.Onboarding_OrganisationalUnits AS targetRows
            WHERE targetRows.RunGuid = @RunGuid
              AND EXISTS
              (
                  SELECT 1
                  FROM SMigration.Onboarding_RunStageSelections AS selection
                  WHERE selection.RunGuid = @RunGuid
                    AND selection.EntityName = N'OrganisationalUnits'
                    AND selection.RowGuid = targetRows.OrganisationalUnitGuid
                    AND selection.RowStatus NOT IN (0,254)
              )

            UNION ALL

            SELECT
                parentRows.OrganisationalUnitGuid,
                parentRows.ParentOrganisationalUnitGuid
            FROM SMigration.Onboarding_OrganisationalUnits AS parentRows
            INNER JOIN RequiredOrganisationalUnits AS childRows
                ON childRows.ParentOrganisationalUnitGuid = parentRows.OrganisationalUnitGuid
            WHERE parentRows.RunGuid = @RunGuid
        )
        DELETE targetRows
        FROM SMigration.Onboarding_OrganisationalUnits AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM RequiredOrganisationalUnits AS requiredRows
              WHERE requiredRows.OrganisationalUnitGuid = targetRows.OrganisationalUnitGuid
          )
        OPTION (MAXRECURSION 100);
        SET @DeletedCount += @@ROWCOUNT;
    END;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_RunStageSelections AS selection WHERE selection.RunGuid = @RunGuid AND selection.EntityName = N'Groups' AND selection.RowStatus NOT IN (0,254))
    BEGIN
        DELETE targetRows
        FROM SMigration.Onboarding_Groups AS targetRows
        WHERE targetRows.RunGuid = @RunGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunStageSelections AS selection
              WHERE selection.RunGuid = @RunGuid
                AND selection.EntityName = N'Groups'
                AND selection.RowGuid = targetRows.GroupGuid
                AND selection.RowStatus NOT IN (0,254)
          );
        SET @DeletedCount += @@ROWCOUNT;
    END;

    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Selection', N'All', N'Prune', @DeletedCount, N'Row-level migration selections were applied to staging before import. Entity tables with no saved rows for that entity were left unchanged.';
END;
GO