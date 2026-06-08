PRINT (N'Create table [SMigration].[Onboarding_Groups]')
GO
CREATE TABLE [SMigration].[Onboarding_Groups] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [GroupGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [DirectoryId] [nvarchar](100) NOT NULL,
  [Code] [nvarchar](30) NOT NULL,
  [Name] [nvarchar](250) NOT NULL,
  [Source] [nvarchar](250) NOT NULL,
  [IsBusinessUnitGroup] [bit] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_Groups] on table [SMigration].[Onboarding_Groups]')
GO
ALTER TABLE [SMigration].[Onboarding_Groups] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_Groups] PRIMARY KEY CLUSTERED ([RunGuid], [GroupGuid]) WITH (FILLFACTOR = 80)
GO