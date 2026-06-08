PRINT (N'Create table [SMigration].[Onboarding_JobTypes]')
GO
CREATE TABLE [SMigration].[Onboarding_JobTypes] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [JobTypeGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [Name] [nvarchar](50) NOT NULL,
  [IsActive] [bit] NOT NULL,
  [SequenceID] [int] NOT NULL,
  [UseTimeSheets] [bit] NOT NULL,
  [UsePlanChecks] [bit] NOT NULL,
  [OrganisationalUnitGuid] [uniqueidentifier] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_JobTypes] on table [SMigration].[Onboarding_JobTypes]')
GO
ALTER TABLE [SMigration].[Onboarding_JobTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_JobTypes] PRIMARY KEY CLUSTERED ([RunGuid], [JobTypeGuid]) WITH (FILLFACTOR = 80)
GO