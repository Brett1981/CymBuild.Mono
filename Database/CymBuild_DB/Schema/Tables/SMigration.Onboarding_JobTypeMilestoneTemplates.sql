PRINT (N'Create table [SMigration].[Onboarding_JobTypeMilestoneTemplates]')
GO
CREATE TABLE [SMigration].[Onboarding_JobTypeMilestoneTemplates] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [JobTypeMilestoneTemplateGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [JobTypeGuid] [uniqueidentifier] NOT NULL,
  [MilestoneTypeGuid] [uniqueidentifier] NOT NULL,
  [Description] [nvarchar](500) NOT NULL,
  [SortOrder] [int] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_JTMT] on table [SMigration].[Onboarding_JobTypeMilestoneTemplates]')
GO
ALTER TABLE [SMigration].[Onboarding_JobTypeMilestoneTemplates] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_JTMT] PRIMARY KEY CLUSTERED ([RunGuid], [JobTypeMilestoneTemplateGuid]) WITH (FILLFACTOR = 80)
GO