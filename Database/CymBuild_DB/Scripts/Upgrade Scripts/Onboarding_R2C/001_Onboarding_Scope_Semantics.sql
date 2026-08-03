SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'SMigration.Onboarding_EntityScope', N'Category') IS NULL
BEGIN
    ALTER TABLE SMigration.Onboarding_EntityScope
        ADD Category NVARCHAR(80) NOT NULL CONSTRAINT DF_Onboarding_EntityScope_Category DEFAULT (N'Operational Configuration');
END;
GO

IF COL_LENGTH(N'SMigration.Onboarding_EntityScope', N'ScopeType') IS NULL
BEGIN
    ALTER TABLE SMigration.Onboarding_EntityScope
        ADD ScopeType NVARCHAR(40) NOT NULL CONSTRAINT DF_Onboarding_EntityScope_ScopeType DEFAULT (N'OnBoardingBucket');
END;
GO

IF COL_LENGTH(N'SMigration.Onboarding_EntityScope', N'IsImplemented') IS NULL
BEGIN
    ALTER TABLE SMigration.Onboarding_EntityScope
        ADD IsImplemented BIT NOT NULL CONSTRAINT DF_Onboarding_EntityScope_IsImplemented DEFAULT (0);
END;
GO

IF COL_LENGTH(N'SMigration.Onboarding_EntityScope', N'IsSupportData') IS NULL
BEGIN
    ALTER TABLE SMigration.Onboarding_EntityScope
        ADD IsSupportData BIT NOT NULL CONSTRAINT DF_Onboarding_EntityScope_IsSupportData DEFAULT (0);
END;
GO

IF COL_LENGTH(N'SMigration.Onboarding_EntityScope', N'HandlerKey') IS NULL
BEGIN
    ALTER TABLE SMigration.Onboarding_EntityScope
        ADD HandlerKey NVARCHAR(100) NOT NULL CONSTRAINT DF_Onboarding_EntityScope_HandlerKey DEFAULT (N'');
END;
GO

IF COL_LENGTH(N'SMigration.Onboarding_EntityScope', N'PrimaryEntityTypeGuid') IS NULL
BEGIN
    ALTER TABLE SMigration.Onboarding_EntityScope
        ADD PrimaryEntityTypeGuid UNIQUEIDENTIFIER NULL;
END;
GO

IF COL_LENGTH(N'SMigration.Onboarding_EntityScope', N'SourceSchemaName') IS NULL
BEGIN
    ALTER TABLE SMigration.Onboarding_EntityScope
        ADD SourceSchemaName SYSNAME NOT NULL CONSTRAINT DF_Onboarding_EntityScope_SourceSchemaName DEFAULT (N'');
END;
GO

IF COL_LENGTH(N'SMigration.Onboarding_EntityScope', N'SourceTableName') IS NULL
BEGIN
    ALTER TABLE SMigration.Onboarding_EntityScope
        ADD SourceTableName SYSNAME NOT NULL CONSTRAINT DF_Onboarding_EntityScope_SourceTableName DEFAULT (N'');
END;
GO

/*
    R2C correction: built-in OnBoarding buckets are controlled by SMigration.Onboarding_EntityScope.
    SCore.EntityTypes.IsOnBoarding is reserved for additional future/configured record types only.
*/
UPDATE et
SET IsOnBoarding = 0
FROM SCore.EntityTypes AS et
WHERE et.RowStatus NOT IN (0,254)
  AND et.Name IN
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
  );
GO

EXEC SMigration.OnboardingEntityScope_Seed;
GO
