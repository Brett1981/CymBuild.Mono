PRINT (N'Create table [SMigration].[Onboarding_ProductJobActivities]')
GO
CREATE TABLE [SMigration].[Onboarding_ProductJobActivities] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [ProductJobActivityGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [ProductGuid] [uniqueidentifier] NOT NULL,
  [JobTypeActivityTypeGuid] [uniqueidentifier] NOT NULL,
  [ActivityTitle] [nvarchar](250) NOT NULL,
  [OffsetDays] [int] NOT NULL,
  [OffsetWeeks] [int] NOT NULL,
  [OffsetMonths] [int] NOT NULL,
  [JobTypeMilestoneTemplateGuid] [uniqueidentifier] NULL,
  [PercentageOfProductValue] [decimal](5, 2) NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_PJA] on table [SMigration].[Onboarding_ProductJobActivities]')
GO
ALTER TABLE [SMigration].[Onboarding_ProductJobActivities] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_PJA] PRIMARY KEY CLUSTERED ([RunGuid], [ProductJobActivityGuid]) WITH (FILLFACTOR = 80)
GO