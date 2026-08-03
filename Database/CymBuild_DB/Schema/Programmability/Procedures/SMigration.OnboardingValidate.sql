SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



/* ================================================================================================
   Validate staged data against target
   ================================================================================================ */
PRINT (N'Create procedure [SMigration].[OnboardingValidate]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingValidate]')
GO



/* ================================================================================================
   Validate staged data against target
   ================================================================================================ */
CREATE PROCEDURE [SMigration].[OnboardingValidate]
    @RunGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    EXEC SMigration.OnboardingRunEntitySelection_ApplyToStage @RunGuid = @RunGuid;

    DELETE FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid;

    /* OnBoarding scope dependency and handler guardrails */
    DECLARE @SelectedState TABLE
    (
        EntityScopeGuid UNIQUEIDENTIFIER NOT NULL,
        EntityCode NVARCHAR(100) NOT NULL PRIMARY KEY,
        EntityName NVARCHAR(200) NOT NULL,
        RequiredDependencyCodes NVARCHAR(1000) NOT NULL,
        IsImplemented BIT NOT NULL,
        IsSupportData BIT NOT NULL,
        ScopeType NVARCHAR(40) NOT NULL,
        IsSelected BIT NOT NULL
    );

    INSERT INTO @SelectedState
    (
        EntityScopeGuid,
        EntityCode,
        EntityName,
        RequiredDependencyCodes,
        IsImplemented,
        IsSupportData,
        ScopeType,
        IsSelected
    )
    SELECT
        scope.Guid AS EntityScopeGuid,
        scope.Code AS EntityCode,
        scope.Name AS EntityName,
        scope.RequiredDependencyCodes,
        scope.IsImplemented,
        scope.IsSupportData,
        scope.ScopeType,
        CONVERT(BIT, ISNULL(selection.IsSelected, scope.DefaultSelected)) AS IsSelected
    FROM SMigration.Onboarding_EntityScope AS scope
    LEFT JOIN SMigration.Onboarding_RunEntitySelections AS selection
        ON selection.RunGuid = @RunGuid
       AND selection.EntityCode = scope.Code
       AND selection.RowStatus NOT IN (0,254)
    WHERE scope.RowStatus NOT IN (0,254)
      AND scope.IsSupportData = 0;

    ;WITH DependencyRows AS
    (
        SELECT
            selected.EntityScopeGuid,
            selected.EntityCode,
            selected.EntityName,
            DependencyCode = LTRIM(RTRIM(split.value))
        FROM @SelectedState AS selected
        CROSS APPLY STRING_SPLIT(selected.RequiredDependencyCodes, N',') AS split
        WHERE selected.IsSelected = 1
          AND ISNULL(LTRIM(RTRIM(split.value)), N'') <> N''
    )
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid,
        EntityName,
        StageTable,
        StageGuid,
        Severity,
        IssueCode,
        IssueMessage
    )
    SELECT
        @RunGuid,
        dependency.EntityCode,
        N'SMigration.Onboarding_RunEntitySelections',
        dependency.EntityScopeGuid,
        N'Error',
        N'ENTITY_SCOPE_DEPENDENCY_NOT_SELECTED',
        CONCAT(N'OnBoarding scope ', dependency.EntityCode, N' requires ', dependency.DependencyCode, N' to also be selected.')
    FROM DependencyRows AS dependency
    LEFT JOIN @SelectedState AS requiredScope
        ON requiredScope.EntityCode = dependency.DependencyCode
       AND requiredScope.IsSelected = 1
    WHERE requiredScope.EntityCode IS NULL;

    /* Configured-only rows are eligible for future OnBoarding work, but have no safe staging/apply handler yet. */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid,
        EntityName,
        StageTable,
        StageGuid,
        Severity,
        IssueCode,
        IssueMessage
    )
    SELECT
        @RunGuid,
        selected.EntityCode,
        selected.ScopeType,
        selected.EntityScopeGuid,
        N'Error',
        N'ENTITY_SCOPE_HANDLER_NOT_IMPLEMENTED',
        CONCAT(N'OnBoarding scope ', selected.EntityCode, N' is configured/eligible but does not yet have an implemented staging/apply handler. Deselect it or add a controlled OnBoarding handler before apply.')
    FROM @SelectedState AS selected
    WHERE selected.IsSelected = 1
      AND ISNULL(selected.IsImplemented, 0) = 0
      AND ISNULL(selected.IsSupportData, 0) = 0;

    /* Address dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Address', N'SMigration.Onboarding_Addresses', s.AddressGuid, N'Error', N'MISSING_COUNTY',
           N'Address references a County Guid that does not exist in target.'
    FROM SMigration.Onboarding_Addresses s
    LEFT JOIN SCrm.Counties c ON c.Guid = s.CountyGuid
    WHERE s.RunGuid = @RunGuid
      AND s.CountyGuid IS NOT NULL
      AND c.ID IS NULL;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Address', N'SMigration.Onboarding_Addresses', s.AddressGuid, N'Error', N'MISSING_COUNTRY',
           N'Address references a Country Guid that does not exist in target.'
    FROM SMigration.Onboarding_Addresses s
    LEFT JOIN SCrm.Countries c ON c.Guid = s.CountryGuid
    WHERE s.RunGuid = @RunGuid
      AND s.CountryGuid IS NOT NULL
      AND c.ID IS NULL;

    /* Contact dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Contact', N'SMigration.Onboarding_Contacts', s.ContactGuid, N'Error', N'MISSING_CONTACT_ACCOUNT',
           N'Contact references a PrimaryAccount Guid that does not exist in target.'
    FROM SMigration.Onboarding_Contacts s
    LEFT JOIN SCrm.Accounts a ON a.Guid = s.PrimaryAccountGuid
    WHERE s.RunGuid = @RunGuid
      AND s.PrimaryAccountGuid IS NOT NULL
      AND a.ID IS NULL;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Contact', N'SMigration.Onboarding_Contacts', s.ContactGuid, N'Error', N'MISSING_CONTACT_ADDRESS',
           N'Contact references a PrimaryAddress Guid that does not exist in target or staged set.'
    FROM SMigration.Onboarding_Contacts s
    LEFT JOIN SCrm.Addresses a ON a.Guid = s.PrimaryAddressGuid
    WHERE s.RunGuid = @RunGuid
      AND a.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_Addresses x WHERE x.RunGuid = @RunGuid AND x.AddressGuid = s.PrimaryAddressGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Contact', N'SMigration.Onboarding_Contacts', s.ContactGuid, N'Error', N'MISSING_CONTACT_TITLE',
           N'Contact references a Title Guid that does not exist in target.'
    FROM SMigration.Onboarding_Contacts s
    LEFT JOIN SCrm.ContactTitles t ON t.Guid = s.TitleGuid
    WHERE s.RunGuid = @RunGuid
      AND s.TitleGuid IS NOT NULL
      AND t.ID IS NULL;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Contact', N'SMigration.Onboarding_Contacts', s.ContactGuid, N'Error', N'MISSING_CONTACT_POSITION',
           N'Contact references a Position Guid that does not exist in target.'
    FROM SMigration.Onboarding_Contacts s
    LEFT JOIN SCrm.ContactPositions p ON p.Guid = s.PositionGuid
    WHERE s.RunGuid = @RunGuid
      AND s.PositionGuid IS NOT NULL
      AND p.ID IS NULL;

    /* Group collisions */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Group', N'SMigration.Onboarding_Groups', s.GroupGuid, N'Warning', N'GROUP_NAME_GUID_MISMATCH',
           N'Target group exists with same Name but different Guid.'
    FROM SMigration.Onboarding_Groups s
    INNER JOIN SCore.Groups g ON g.Name = s.Name AND g.Guid <> s.GroupGuid
    WHERE s.RunGuid = @RunGuid;

    /* OU dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'OrganisationalUnit', N'SMigration.Onboarding_OrganisationalUnits', s.OrganisationalUnitGuid, N'Error', N'MISSING_DEFAULT_SECURITY_GROUP',
           N'OrganisationalUnit default security group does not exist in target or staged set.'
    FROM SMigration.Onboarding_OrganisationalUnits s
    LEFT JOIN SCore.Groups g ON g.Guid = s.DefaultSecurityGroupGuid
    WHERE s.RunGuid = @RunGuid
      AND g.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_Groups x WHERE x.RunGuid = @RunGuid AND x.GroupGuid = s.DefaultSecurityGroupGuid);

    /* Identity dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Identity', N'SMigration.Onboarding_Identities', s.IdentityGuid, N'Error', N'MISSING_IDENTITY_OU',
           N'Identity references an OrganisationalUnit Guid that does not exist in target or staged set.'
    FROM SMigration.Onboarding_Identities s
    LEFT JOIN SCore.OrganisationalUnits ou ON ou.Guid = s.OrganisationalUnitGuid
    WHERE s.RunGuid = @RunGuid
      AND ou.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_OrganisationalUnits x WHERE x.RunGuid = @RunGuid AND x.OrganisationalUnitGuid = s.OrganisationalUnitGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Identity', N'SMigration.Onboarding_Identities', s.IdentityGuid, N'Error', N'MISSING_IDENTITY_CONTACT',
           N'Identity references a Contact Guid that does not exist in target or staged set.'
    FROM SMigration.Onboarding_Identities s
    LEFT JOIN SCrm.Contacts c ON c.Guid = s.ContactGuid
    WHERE s.RunGuid = @RunGuid
      AND c.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_Contacts x WHERE x.RunGuid = @RunGuid AND x.ContactGuid = s.ContactGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Identity', N'SMigration.Onboarding_Identities', s.IdentityGuid, N'Warning', N'IDENTITY_EMAIL_GUID_MISMATCH',
           N'Target identity exists with same EmailAddress but different Guid.'
    FROM SMigration.Onboarding_Identities s
    INNER JOIN SCore.Identities i ON i.EmailAddress = s.EmailAddress AND i.Guid <> s.IdentityGuid
    WHERE s.RunGuid = @RunGuid;

    /* UserGroup dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'UserGroup', N'SMigration.Onboarding_UserGroups', s.UserGroupGuid, N'Error', N'MISSING_USERGROUP_IDENTITY',
           N'UserGroup references an Identity Guid not present in target or staged set.'
    FROM SMigration.Onboarding_UserGroups s
    LEFT JOIN SCore.Identities i ON i.Guid = s.IdentityGuid
    WHERE s.RunGuid = @RunGuid
      AND i.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_Identities x WHERE x.RunGuid = @RunGuid AND x.IdentityGuid = s.IdentityGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'UserGroup', N'SMigration.Onboarding_UserGroups', s.UserGroupGuid, N'Error', N'MISSING_USERGROUP_GROUP',
           N'UserGroup references a Group Guid not present in target or staged set.'
    FROM SMigration.Onboarding_UserGroups s
    LEFT JOIN SCore.Groups g ON g.Guid = s.GroupGuid
    WHERE s.RunGuid = @RunGuid
      AND g.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_Groups x WHERE x.RunGuid = @RunGuid AND x.GroupGuid = s.GroupGuid);

          /* WorkflowTransition missing Workflow */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid,
        EntityName,
        StageTable,
        StageGuid,
        Severity,
        IssueCode,
        IssueMessage
    )
    SELECT
        @RunGuid,
        N'WorkflowTransition',
        N'SMigration.Onboarding_WorkflowTransitions',
        s.WorkflowTransitionGuid,
        N'Error',
        N'MISSING_WORKFLOW_FOR_TRANSITION',
        N'WorkflowTransition references a Workflow that does not exist in target or staged workflow set.'
    FROM SMigration.Onboarding_WorkflowTransitions AS s
    LEFT JOIN SCore.Workflow AS wf
        ON wf.Guid = s.WorkflowGuid
    WHERE s.RunGuid = @RunGuid
      AND wf.ID IS NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Workflows AS sw
          WHERE sw.RunGuid = @RunGuid
            AND sw.WorkflowGuid = s.WorkflowGuid
      );

    /* WorkflowTransition missing FromStatus */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid,
        EntityName,
        StageTable,
        StageGuid,
        Severity,
        IssueCode,
        IssueMessage
    )
    SELECT
        @RunGuid,
        N'WorkflowTransition',
        N'SMigration.Onboarding_WorkflowTransitions',
        s.WorkflowTransitionGuid,
        N'Error',
        N'MISSING_FROM_WORKFLOW_STATUS',
        N'WorkflowTransition FromStatusGuid does not exist in target or staged WorkflowStatus.'
    FROM SMigration.Onboarding_WorkflowTransitions AS s
    LEFT JOIN SCore.WorkflowStatus AS ws
        ON ws.Guid = s.FromStatusGuid
    WHERE s.RunGuid = @RunGuid
      AND s.FromStatusGuid <> '00000000-0000-0000-0000-000000000000'
      AND ws.ID IS NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_WorkflowStatuses AS stagedStatus
          WHERE stagedStatus.RunGuid = @RunGuid
            AND stagedStatus.WorkflowStatusGuid = s.FromStatusGuid
      );

    /* WorkflowTransition missing ToStatus */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid,
        EntityName,
        StageTable,
        StageGuid,
        Severity,
        IssueCode,
        IssueMessage
    )
    SELECT
        @RunGuid,
        N'WorkflowTransition',
        N'SMigration.Onboarding_WorkflowTransitions',
        s.WorkflowTransitionGuid,
        N'Error',
        N'MISSING_TO_WORKFLOW_STATUS',
        N'WorkflowTransition ToStatusGuid does not exist in target or staged WorkflowStatus.'
    FROM SMigration.Onboarding_WorkflowTransitions AS s
    LEFT JOIN SCore.WorkflowStatus AS ws
        ON ws.Guid = s.ToStatusGuid
    WHERE s.RunGuid = @RunGuid
      AND s.ToStatusGuid <> '00000000-0000-0000-0000-000000000000'
      AND ws.ID IS NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_WorkflowStatuses AS stagedStatus
          WHERE stagedStatus.RunGuid = @RunGuid
            AND stagedStatus.WorkflowStatusGuid = s.ToStatusGuid
      );

    /* Workflow dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'WorkflowStatusNotificationGroup', N'SMigration.Onboarding_WorkflowStatusNotificationGroups', s.WorkflowNotificationGroupGuid, N'Error', N'MISSING_WORKFLOW',
        N'WorkflowStatusNotificationGroup references a Workflow Guid that does not exist in target or staged workflow set.'
    FROM SMigration.Onboarding_WorkflowStatusNotificationGroups AS s
    LEFT JOIN SCore.Workflow AS wf
        ON wf.Guid = s.WorkflowGuid
    WHERE s.RunGuid = @RunGuid
      AND wf.ID IS NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Workflows AS sw
          WHERE sw.RunGuid = @RunGuid
            AND sw.WorkflowGuid = s.WorkflowGuid
      );


    /* Workflow notification group missing WorkflowStatus */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'WorkflowStatusNotificationGroup', N'SMigration.Onboarding_WorkflowStatusNotificationGroups', s.WorkflowNotificationGroupGuid, N'Error', N'MISSING_WORKFLOW_STATUS',
        N'WorkflowStatusNotificationGroup references a WorkflowStatus Guid that does not exist in target or staged workflow statuses.'
    FROM SMigration.Onboarding_WorkflowStatusNotificationGroups AS s
    LEFT JOIN SCore.WorkflowStatus AS ws
        ON ws.Guid = s.WorkflowStatusGuid
    WHERE s.RunGuid = @RunGuid
      AND ws.ID IS NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_WorkflowStatuses AS stagedStatus
          WHERE stagedStatus.RunGuid = @RunGuid
            AND stagedStatus.WorkflowStatusGuid = s.WorkflowStatusGuid
      );

    /* Job setup dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'JobType', N'SMigration.Onboarding_JobTypes', s.JobTypeGuid, N'Error', N'MISSING_JOBTYPE_OU',
           N'JobType references an OrganisationalUnit Guid that does not exist in target or staged set.'
    FROM SMigration.Onboarding_JobTypes s
    LEFT JOIN SCore.OrganisationalUnits ou ON ou.Guid = s.OrganisationalUnitGuid
    WHERE s.RunGuid = @RunGuid
      AND ou.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_OrganisationalUnits x WHERE x.RunGuid = @RunGuid AND x.OrganisationalUnitGuid = s.OrganisationalUnitGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Product', N'SMigration.Onboarding_Products', s.ProductGuid, N'Error', N'MISSING_PRODUCT_JOBTYPE',
           N'Product references a CreatedJobType Guid not present in target or staged set.'
    FROM SMigration.Onboarding_Products s
    LEFT JOIN SJob.JobTypes jt ON jt.Guid = s.CreatedJobTypeGuid
    WHERE s.RunGuid = @RunGuid
      AND jt.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_JobTypes x WHERE x.RunGuid = @RunGuid AND x.JobTypeGuid = s.CreatedJobTypeGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Product', N'SMigration.Onboarding_Products', s.ProductGuid, N'Error', N'MISSING_RIBA_STAGE',
           N'Product references a RibaStage Guid that does not exist in target.'
    FROM SMigration.Onboarding_Products s
    LEFT JOIN SJob.RibaStages rs ON rs.Guid = s.RibaStageGuid
    WHERE s.RunGuid = @RunGuid
      AND s.RibaStageGuid IS NOT NULL
      AND rs.ID IS NULL;

    /* warnings */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'JobType', N'SMigration.Onboarding_JobTypes', s.JobTypeGuid, N'Warning', N'JOBTYPE_NAME_GUID_MISMATCH',
           N'Target JobType exists with same Name but different Guid.'
    FROM SMigration.Onboarding_JobTypes s
    INNER JOIN SJob.JobTypes t ON t.Name = s.Name AND t.Guid <> s.JobTypeGuid
    WHERE s.RunGuid = @RunGuid;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'ActivityType', N'SMigration.Onboarding_ActivityTypes', s.ActivityTypeGuid, N'Warning', N'ACTIVITY_NAME_GUID_MISMATCH',
           N'Target ActivityType exists with same Name but different Guid.'
    FROM SMigration.Onboarding_ActivityTypes s
    INNER JOIN SJob.ActivityTypes t ON t.Name = s.Name AND t.Guid <> s.ActivityTypeGuid
    WHERE s.RunGuid = @RunGuid;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'MilestoneType', N'SMigration.Onboarding_MilestoneTypes', s.MilestoneTypeGuid, N'Warning', N'MILESTONE_CODE_GUID_MISMATCH',
           N'Target MilestoneType exists with same Code but different Guid.'
    FROM SMigration.Onboarding_MilestoneTypes s
    INNER JOIN SJob.MilestoneTypes t ON t.Code = s.Code AND t.Guid <> s.MilestoneTypeGuid
    WHERE s.RunGuid = @RunGuid;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Product', N'SMigration.Onboarding_Products', s.ProductGuid, N'Warning', N'PRODUCT_CODE_GUID_MISMATCH',
           N'Target Product exists with same Code but different Guid.'
    FROM SMigration.Onboarding_Products s
    INNER JOIN SProd.Products t ON t.Code = s.Code AND t.Guid <> s.ProductGuid
    WHERE s.RunGuid = @RunGuid;

    DECLARE @Err INT = 0, @Warn INT = 0;
    SELECT @Err = COUNT(*) FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid AND Severity = N'Error';
    SELECT @Warn = COUNT(*) FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid AND Severity = N'Warning';
    DECLARE @FullErrorCount INT = @Err + @Warn
    DECLARE @FullError NVarchar(50) = CONCAT(N'Errors=', @Err, N'; Warnings=', @Warn);
    EXEC SMigration.OnboardingLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'Validate',
        @EntityName = N'All',
        @ActionName = N'Summary',
        @AffectedCount = @FullErrorCount,
        @Details = @FullError

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
END

GO