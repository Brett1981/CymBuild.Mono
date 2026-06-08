PRINT (N'Create table [SMigration].[Onboarding_UserGroups]')
GO
CREATE TABLE [SMigration].[Onboarding_UserGroups] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [UserGroupGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [IdentityGuid] [uniqueidentifier] NOT NULL,
  [GroupGuid] [uniqueidentifier] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_UserGroups] on table [SMigration].[Onboarding_UserGroups]')
GO
ALTER TABLE [SMigration].[Onboarding_UserGroups] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_UserGroups] PRIMARY KEY CLUSTERED ([RunGuid], [UserGroupGuid]) WITH (FILLFACTOR = 80)
GO