SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingEntityScope_Seed]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingEntityScope_Seed]')
GO

CREATE PROCEDURE [SMigration].[OnboardingEntityScope_Seed]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Seed TABLE
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        Code NVARCHAR(100) NOT NULL PRIMARY KEY,
        Name NVARCHAR(200) NOT NULL,
        StageTableName SYSNAME NOT NULL,
        DisplayOrder INT NOT NULL,
        DefaultSelected BIT NOT NULL,
        CanDeselect BIT NOT NULL,
        IsRequired BIT NOT NULL,
        RequiredDependencyCodes NVARCHAR(1000) NOT NULL,
        Description NVARCHAR(500) NOT NULL,
        Category NVARCHAR(80) NOT NULL,
        ScopeType NVARCHAR(40) NOT NULL,
        IsImplemented BIT NOT NULL,
        IsSupportData BIT NOT NULL,
        HandlerKey NVARCHAR(100) NOT NULL,
        PrimaryEntityTypeName NVARCHAR(250) NULL,
        SourceSchemaName SYSNAME NOT NULL,
        SourceTableName SYSNAME NOT NULL
    );

    /*
        R2C terminology:
        - OnBoarding scope rows are migration buckets selected per run.
        - SCore.EntityTypes.IsOnBoarding is only an eligibility flag for additional future/configured record types.
        - Physical tables are implementation detail and may be support-only.

        This seed deliberately does not update SCore.EntityTypes.IsOnBoarding.
    */
    INSERT INTO @Seed
    (
        Guid,
        Code,
        Name,
        StageTableName,
        DisplayOrder,
        DefaultSelected,
        CanDeselect,
        IsRequired,
        RequiredDependencyCodes,
        Description,
        Category,
        ScopeType,
        IsImplemented,
        IsSupportData,
        HandlerKey,
        PrimaryEntityTypeName,
        SourceSchemaName,
        SourceTableName
    )
    VALUES
        ('34e5fb6d-878d-4f63-b74f-771eeb243501', N'Groups', N'Groups', N'SMigration.Onboarding_Groups', 10, 1, 1, 0, N'', N'Security groups required by users, organisational units and workflow notification rules.', N'Access Foundation', N'OnBoardingBucket', 1, 0, N'Groups', N'Groups', N'SCore', N'Groups'),
        ('d791485d-45d6-4282-ad62-ee594299e59c', N'OrganisationalUnits', N'Organisational Units', N'SMigration.Onboarding_OrganisationalUnits', 20, 1, 1, 0, N'Groups', N'Business unit and child organisational unit structure.', N'Access Foundation', N'OnBoardingBucket', 1, 0, N'OrganisationalUnits', N'OrganisationalUnits', N'SCore', N'OrganisationalUnits'),
        ('363c6fd4-2712-4841-913f-bc8cc303f2d8', N'Identities', N'Users / Identities', N'SMigration.Onboarding_Identities', 30, 1, 1, 0, N'OrganisationalUnits', N'User identity records linked to source organisational units.', N'Access Foundation', N'OnBoardingBucket', 1, 0, N'Identities', N'Identities', N'SCore', N'Identities'),
        ('2ee2d088-49f7-42a5-b0b0-28f0d82d3320', N'UserGroups', N'User Group Memberships', N'SMigration.Onboarding_UserGroups', 40, 1, 1, 0, N'Groups,Identities', N'User-to-group memberships for staged identities.', N'Access Foundation', N'OnBoardingBucket', 1, 0, N'UserGroups', N'UserGroups', N'SCore', N'UserGroups'),

        ('4c0e8423-d31d-4f4c-a9cf-e42f50fb7421', N'Workflows', N'Workflows', N'SMigration.Onboarding_Workflows', 100, 1, 1, 0, N'OrganisationalUnits', N'Workflow definitions for the selected business unit.', N'Operational Configuration', N'OnBoardingBucket', 1, 0, N'Workflows', NULL, N'SCore', N'Workflow'),
        ('b63f1c84-0286-4fdc-8f81-4b18fa468dc5', N'WorkflowStatuses', N'Workflow Statuses', N'SMigration.Onboarding_WorkflowStatuses', 105, 1, 1, 0, N'Workflows', N'Workflow statuses referenced by staged workflows, transitions and notification groups.', N'Operational Configuration', N'OnBoardingBucket', 1, 0, N'WorkflowStatuses', NULL, N'SCore', N'WorkflowStatus'),
        ('b98b2ef9-2b2d-4f33-a85a-0df8ff4fd9ed', N'WorkflowTransitions', N'Workflow Transitions', N'SMigration.Onboarding_WorkflowTransitions', 108, 1, 1, 0, N'Workflows,WorkflowStatuses', N'Workflow transitions for staged workflow definitions.', N'Operational Configuration', N'OnBoardingBucket', 1, 0, N'WorkflowTransitions', NULL, N'SCore', N'WorkflowTransition'),
        ('9f1b2e81-9082-4f4a-8d61-22dc9d19df56', N'WorkflowStatusNotificationGroups', N'Workflow Notification Groups', N'SMigration.Onboarding_WorkflowStatusNotificationGroups', 110, 1, 1, 0, N'WorkflowStatuses,Groups', N'Workflow status notification group permissions for staged groups.', N'Operational Configuration', N'OnBoardingBucket', 1, 0, N'WorkflowStatusNotificationGroups', NULL, N'SCore', N'WorkflowStatusNotificationGroups'),
        ('a7a8edc9-cf6a-4a07-bf42-34c41f317095', N'JobTypes', N'Job Types', N'SMigration.Onboarding_JobTypes', 120, 1, 1, 0, N'OrganisationalUnits', N'Job type setup linked to staged organisational units.', N'Operational Configuration', N'OnBoardingBucket', 1, 0, N'JobTypes', N'JobTypes', N'SJob', N'JobTypes'),
        ('70245f10-58cd-41d2-9f24-f64e9c5937a1', N'ActivityTypes', N'Activity Types', N'SMigration.Onboarding_ActivityTypes', 130, 1, 1, 0, N'', N'Activity type setup used by job type activity templates.', N'Operational Configuration', N'OnBoardingBucket', 1, 0, N'ActivityTypes', N'ActivityTypes', N'SJob', N'ActivityTypes'),
        ('0bdbb779-e3a6-4a15-8f05-4db4ce094af3', N'MilestoneTypes', N'Milestone Types', N'SMigration.Onboarding_MilestoneTypes', 140, 1, 1, 0, N'', N'Milestone type setup used by job type milestone templates.', N'Operational Configuration', N'OnBoardingBucket', 1, 0, N'MilestoneTypes', N'MilestoneTypes', N'SJob', N'MilestoneTypes'),
        ('e811d028-9e2c-4c29-b92a-8296970c3f2f', N'Products', N'Products', N'SMigration.Onboarding_Products', 150, 1, 1, 0, N'JobTypes', N'Product setup linked to created job types.', N'Operational Configuration', N'OnBoardingBucket', 1, 0, N'Products', N'Products', N'SProd', N'Products'),
        ('71945bc5-a2eb-4d72-bc25-6327a860a8b6', N'JobTypeActivityTypes', N'Job Type Activity Templates', N'SMigration.Onboarding_JobTypeActivityTypes', 160, 1, 1, 0, N'JobTypes,ActivityTypes', N'Job type to activity type template relationships.', N'Operational Configuration', N'OnBoardingBucket', 1, 0, N'JobTypeActivityTypes', NULL, N'SJob', N'JobTypeActivityTypes'),
        ('9d091c29-b679-4d79-a0d1-d2386ab96976', N'JobTypeMilestoneTemplates', N'Job Type Milestone Templates', N'SMigration.Onboarding_JobTypeMilestoneTemplates', 170, 1, 1, 0, N'JobTypes,MilestoneTypes', N'Job type milestone template relationships.', N'Operational Configuration', N'OnBoardingBucket', 1, 0, N'JobTypeMilestoneTemplates', NULL, N'SJob', N'JobTypeMilestoneTemplates'),
        ('8f7b257d-1784-4414-89c8-b87092db4744', N'ProductJobActivities', N'Product Job Activity Defaults', N'SMigration.Onboarding_ProductJobActivities', 180, 1, 1, 0, N'Products,JobTypeActivityTypes', N'Product activity defaults linked to products and job type activities.', N'Operational Configuration', N'OnBoardingBucket', 1, 0, N'ProductJobActivities', NULL, N'SProd', N'ProductJobActivities');

    UPDATE supportScope
    SET
        RowStatus = 254,
        IsSupportData = 1,
        IsImplemented = 0,
        ScopeType = N'SupportData',
        Category = N'Internal / Support Data',
        UpdatedUtc = SYSUTCDATETIME()
    FROM SMigration.Onboarding_EntityScope AS supportScope
    WHERE supportScope.Code IN (N'Addresses', N'Contacts')
      AND supportScope.StageTableName IN (N'SMigration.Onboarding_Addresses', N'SMigration.Onboarding_Contacts');

    UPDATE target
    SET
        RowStatus = 1,
        Name = source.Name,
        StageTableName = source.StageTableName,
        DisplayOrder = source.DisplayOrder,
        DefaultSelected = source.DefaultSelected,
        CanDeselect = source.CanDeselect,
        IsRequired = source.IsRequired,
        RequiredDependencyCodes = source.RequiredDependencyCodes,
        Description = source.Description,
        Category = source.Category,
        ScopeType = source.ScopeType,
        IsImplemented = source.IsImplemented,
        IsSupportData = source.IsSupportData,
        HandlerKey = source.HandlerKey,
        PrimaryEntityTypeGuid = entityType.Guid,
        SourceSchemaName = source.SourceSchemaName,
        SourceTableName = source.SourceTableName,
        UpdatedUtc = SYSUTCDATETIME()
    FROM SMigration.Onboarding_EntityScope AS target
    INNER JOIN @Seed AS source
        ON source.Code = target.Code
    OUTER APPLY
    (
        SELECT TOP (1) et.Guid
        FROM SCore.EntityTypes AS et
        WHERE et.RowStatus NOT IN (0,254)
          AND source.PrimaryEntityTypeName IS NOT NULL
          AND et.Name IN (source.PrimaryEntityTypeName, REPLACE(source.PrimaryEntityTypeName, N' ', N''))
        ORDER BY et.ID
    ) AS entityType;

    DECLARE
        @Guid UNIQUEIDENTIFIER,
        @Code NVARCHAR(100),
        @Name NVARCHAR(200),
        @StageTableName SYSNAME,
        @DisplayOrder INT,
        @DefaultSelected BIT,
        @CanDeselect BIT,
        @IsRequired BIT,
        @RequiredDependencyCodes NVARCHAR(1000),
        @Description NVARCHAR(500),
        @Category NVARCHAR(80),
        @ScopeType NVARCHAR(40),
        @IsImplemented BIT,
        @IsSupportData BIT,
        @HandlerKey NVARCHAR(100),
        @PrimaryEntityTypeGuid UNIQUEIDENTIFIER,
        @SourceSchemaName SYSNAME,
        @SourceTableName SYSNAME;

    DECLARE seed_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            source.Guid,
            source.Code,
            source.Name,
            source.StageTableName,
            source.DisplayOrder,
            source.DefaultSelected,
            source.CanDeselect,
            source.IsRequired,
            source.RequiredDependencyCodes,
            source.Description,
            source.Category,
            source.ScopeType,
            source.IsImplemented,
            source.IsSupportData,
            source.HandlerKey,
            entityType.Guid,
            source.SourceSchemaName,
            source.SourceTableName
        FROM @Seed AS source
        OUTER APPLY
        (
            SELECT TOP (1) et.Guid
            FROM SCore.EntityTypes AS et
            WHERE et.RowStatus NOT IN (0,254)
              AND source.PrimaryEntityTypeName IS NOT NULL
              AND et.Name IN (source.PrimaryEntityTypeName, REPLACE(source.PrimaryEntityTypeName, N' ', N''))
            ORDER BY et.ID
        ) AS entityType
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SMigration.Onboarding_EntityScope AS existing
            WHERE existing.Code = source.Code
        )
        ORDER BY source.DisplayOrder;

    OPEN seed_cursor;
    FETCH NEXT FROM seed_cursor INTO @Guid, @Code, @Name, @StageTableName, @DisplayOrder, @DefaultSelected, @CanDeselect, @IsRequired, @RequiredDependencyCodes, @Description, @Category, @ScopeType, @IsImplemented, @IsSupportData, @HandlerKey, @PrimaryEntityTypeGuid, @SourceSchemaName, @SourceTableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @Guid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Onboarding_EntityScope';

        INSERT INTO SMigration.Onboarding_EntityScope
        (
            Guid,
            RowStatus,
            Code,
            Name,
            StageTableName,
            DisplayOrder,
            DefaultSelected,
            CanDeselect,
            IsRequired,
            RequiredDependencyCodes,
            Description,
            Category,
            ScopeType,
            IsImplemented,
            IsSupportData,
            HandlerKey,
            PrimaryEntityTypeGuid,
            SourceSchemaName,
            SourceTableName,
            CreatedUtc,
            UpdatedUtc
        )
        VALUES
        (
            @Guid,
            1,
            @Code,
            @Name,
            @StageTableName,
            @DisplayOrder,
            @DefaultSelected,
            @CanDeselect,
            @IsRequired,
            @RequiredDependencyCodes,
            @Description,
            @Category,
            @ScopeType,
            @IsImplemented,
            @IsSupportData,
            @HandlerKey,
            @PrimaryEntityTypeGuid,
            @SourceSchemaName,
            @SourceTableName,
            SYSUTCDATETIME(),
            SYSUTCDATETIME()
        );

        FETCH NEXT FROM seed_cursor INTO @Guid, @Code, @Name, @StageTableName, @DisplayOrder, @DefaultSelected, @CanDeselect, @IsRequired, @RequiredDependencyCodes, @Description, @Category, @ScopeType, @IsImplemented, @IsSupportData, @HandlerKey, @PrimaryEntityTypeGuid, @SourceSchemaName, @SourceTableName;
    END;

    CLOSE seed_cursor;
    DEALLOCATE seed_cursor;

    /* Discover only entity types explicitly approved for OnBoarding as configured-only candidate rows. */
    ;WITH CandidateEntityHobts AS
    (
        SELECT
            et.Guid AS EntityTypeGuid,
            et.Name AS EntityTypeName,
            eh.SchemaName,
            eh.ObjectName,
            ROW_NUMBER() OVER
            (
                PARTITION BY et.Guid
                ORDER BY
                    CASE WHEN eh.IsMainHoBT = 1 THEN 0 ELSE 1 END,
                    eh.SchemaName,
                    eh.ObjectName,
                    eh.ID
            ) AS HoBTRowNumber
        FROM SCore.EntityTypes AS et
        INNER JOIN SCore.EntityHobts AS eh
            ON eh.EntityTypeID = et.ID
           AND eh.RowStatus NOT IN (0,254)
        WHERE et.RowStatus NOT IN (0,254)
          AND ISNULL(et.IsMetaData, 0) = 0
          AND ISNULL(et.IsOnBoarding, 0) = 1
          AND ISNULL(et.Name, N'') <> N''
          AND et.Name NOT IN
          (
              N'Addresses',
              N'Contacts',
              N'Groups',
              N'Identities',
              N'Products',
              N'OrganisationalUnits',
              N'Organisational Units',
              N'UserGroups',
              N'User Groups',
              N'JobTypes',
              N'Job Types',
              N'ActivityTypes',
              N'Activity Types',
              N'MilestoneTypes',
              N'Milestone Types'
          )
          AND ISNULL(eh.SchemaName, N'') <> N''
          AND ISNULL(eh.ObjectName, N'') <> N''
    ),
    ChosenEntityHobts AS
    (
        SELECT
            candidate.EntityTypeGuid,
            candidate.EntityTypeName,
            candidate.SchemaName,
            candidate.ObjectName
        FROM CandidateEntityHobts AS candidate
        WHERE candidate.HoBTRowNumber = 1
    ),
    DiscoverySource AS
    (
        SELECT
            chosen.EntityTypeGuid,
            LEFT(chosen.EntityTypeName, 100) AS ScopeCode,
            LEFT(chosen.EntityTypeName, 200) AS ScopeName,
            CONVERT(NVARCHAR(128), LEFT(CONCAT(chosen.SchemaName, N'.', chosen.ObjectName), 128)) AS StageTableName,
            10000 + ROW_NUMBER() OVER (ORDER BY chosen.EntityTypeName, chosen.SchemaName, chosen.ObjectName) AS DisplayOrder,
            LEFT(CONCAT(N'EntityType is marked IsOnBoarding = 1 and is eligible for future OnBoarding support from ', chosen.SchemaName, N'.', chosen.ObjectName, N'. It is persisted in run scope, but has no staging/apply handler yet.'), 500) AS Description,
            CONVERT(CHAR(32), HASHBYTES(N'MD5', CONCAT(N'SMigration.Onboarding_EntityScope:', CONVERT(NVARCHAR(36), chosen.EntityTypeGuid))), 2) AS GuidHash,
            chosen.SchemaName,
            chosen.ObjectName
        FROM ChosenEntityHobts AS chosen
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM @Seed AS seed
            WHERE seed.Code = chosen.EntityTypeName
               OR seed.SourceSchemaName + N'.' + seed.SourceTableName = chosen.SchemaName + N'.' + chosen.ObjectName
        )
    )
    SELECT
        CONVERT(UNIQUEIDENTIFIER, STUFF(STUFF(STUFF(STUFF(source.GuidHash, 21, 0, N'-'), 17, 0, N'-'), 13, 0, N'-'), 9, 0, N'-')) AS ScopeGuid,
        source.ScopeCode,
        source.ScopeName,
        source.StageTableName,
        source.DisplayOrder,
        source.Description,
        source.EntityTypeGuid,
        source.SchemaName,
        source.ObjectName
    INTO #OnboardingEligibleEntityScope
    FROM DiscoverySource AS source;

    UPDATE existing
    SET
        RowStatus = 1,
        Name = eligible.ScopeName,
        StageTableName = eligible.StageTableName,
        DisplayOrder = eligible.DisplayOrder,
        DefaultSelected = 1,
        CanDeselect = 1,
        IsRequired = 0,
        RequiredDependencyCodes = N'',
        Description = eligible.Description,
        Category = N'Additional Eligible Record Types',
        ScopeType = N'EligibleEntityType',
        IsImplemented = 0,
        IsSupportData = 0,
        HandlerKey = N'',
        PrimaryEntityTypeGuid = eligible.EntityTypeGuid,
        SourceSchemaName = eligible.SchemaName,
        SourceTableName = eligible.ObjectName,
        UpdatedUtc = SYSUTCDATETIME()
    FROM SMigration.Onboarding_EntityScope AS existing
    INNER JOIN #OnboardingEligibleEntityScope AS eligible
        ON existing.Code = eligible.ScopeCode;

    DECLARE
        @DiscoveredGuid UNIQUEIDENTIFIER,
        @DiscoveredCode NVARCHAR(100),
        @DiscoveredName NVARCHAR(200),
        @DiscoveredStageTableName SYSNAME,
        @DiscoveredDisplayOrder INT,
        @DiscoveredDescription NVARCHAR(500),
        @DiscoveredEntityTypeGuid UNIQUEIDENTIFIER,
        @DiscoveredSchemaName SYSNAME,
        @DiscoveredObjectName SYSNAME;

    DECLARE discovered_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            eligible.ScopeGuid,
            eligible.ScopeCode,
            eligible.ScopeName,
            eligible.StageTableName,
            eligible.DisplayOrder,
            eligible.Description,
            eligible.EntityTypeGuid,
            eligible.SchemaName,
            eligible.ObjectName
        FROM #OnboardingEligibleEntityScope AS eligible
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SMigration.Onboarding_EntityScope AS existing
            WHERE existing.Code = eligible.ScopeCode
        )
        ORDER BY
            eligible.DisplayOrder,
            eligible.ScopeCode;

    OPEN discovered_cursor;
    FETCH NEXT FROM discovered_cursor INTO @DiscoveredGuid, @DiscoveredCode, @DiscoveredName, @DiscoveredStageTableName, @DiscoveredDisplayOrder, @DiscoveredDescription, @DiscoveredEntityTypeGuid, @DiscoveredSchemaName, @DiscoveredObjectName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @DiscoveredGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Onboarding_EntityScope';

        INSERT INTO SMigration.Onboarding_EntityScope
        (
            Guid,
            RowStatus,
            Code,
            Name,
            StageTableName,
            DisplayOrder,
            DefaultSelected,
            CanDeselect,
            IsRequired,
            RequiredDependencyCodes,
            Description,
            Category,
            ScopeType,
            IsImplemented,
            IsSupportData,
            HandlerKey,
            PrimaryEntityTypeGuid,
            SourceSchemaName,
            SourceTableName,
            CreatedUtc,
            UpdatedUtc
        )
        VALUES
        (
            @DiscoveredGuid,
            1,
            @DiscoveredCode,
            @DiscoveredName,
            @DiscoveredStageTableName,
            @DiscoveredDisplayOrder,
            1,
            1,
            0,
            N'',
            @DiscoveredDescription,
            N'Additional Eligible Record Types',
            N'EligibleEntityType',
            0,
            0,
            N'',
            @DiscoveredEntityTypeGuid,
            @DiscoveredSchemaName,
            @DiscoveredObjectName,
            SYSUTCDATETIME(),
            SYSUTCDATETIME()
        );

        FETCH NEXT FROM discovered_cursor INTO @DiscoveredGuid, @DiscoveredCode, @DiscoveredName, @DiscoveredStageTableName, @DiscoveredDisplayOrder, @DiscoveredDescription, @DiscoveredEntityTypeGuid, @DiscoveredSchemaName, @DiscoveredObjectName;
    END;

    CLOSE discovered_cursor;
    DEALLOCATE discovered_cursor;

    UPDATE obsolete
    SET
        RowStatus = 254,
        UpdatedUtc = SYSUTCDATETIME()
    FROM SMigration.Onboarding_EntityScope AS obsolete
    WHERE obsolete.RowStatus NOT IN (0,254)
      AND obsolete.ScopeType = N'EligibleEntityType'
      AND NOT EXISTS
      (
          SELECT 1
          FROM #OnboardingEligibleEntityScope AS eligible
          WHERE eligible.ScopeCode = obsolete.Code
      );

    DROP TABLE #OnboardingEligibleEntityScope;

    DECLARE ensure_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT es.Guid
        FROM SMigration.Onboarding_EntityScope AS es
        WHERE es.RowStatus NOT IN (0,254);

    OPEN ensure_cursor;
    FETCH NEXT FROM ensure_cursor INTO @Guid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @Guid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Onboarding_EntityScope';

        FETCH NEXT FROM ensure_cursor INTO @Guid;
    END;

    CLOSE ensure_cursor;
    DEALLOCATE ensure_cursor;
END;
GO