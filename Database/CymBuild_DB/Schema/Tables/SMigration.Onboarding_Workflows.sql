PRINT (N'Create table [SMigration].[Onboarding_Workflows]')
GO
CREATE TABLE [SMigration].[Onboarding_Workflows] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [WorkflowGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [Name] [nvarchar](250) NOT NULL,
  [OrganisationalUnitGuid] [uniqueidentifier] NULL,
  [EntityTypeGuid] [uniqueidentifier] NULL,
  [EntityHoBTGuid] [uniqueidentifier] NULL,
  [Description] [nvarchar](max) NULL,
  [Enabled] [bit] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_Workflows] on table [SMigration].[Onboarding_Workflows]')
GO
ALTER TABLE [SMigration].[Onboarding_Workflows] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_Workflows] PRIMARY KEY CLUSTERED ([RunGuid], [WorkflowGuid]) WITH (FILLFACTOR = 90)
GO