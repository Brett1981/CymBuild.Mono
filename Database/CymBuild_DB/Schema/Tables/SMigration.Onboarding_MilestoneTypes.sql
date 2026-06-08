PRINT (N'Create table [SMigration].[Onboarding_MilestoneTypes]')
GO
CREATE TABLE [SMigration].[Onboarding_MilestoneTypes] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [MilestoneTypeGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [Code] [nvarchar](20) NOT NULL,
  [Name] [nvarchar](250) NOT NULL,
  [IsActive] [bit] NOT NULL,
  [IsInvoiceTrigger] [bit] NOT NULL,
  [IsReviewRequired] [bit] NOT NULL,
  [HelpText] [nvarchar](2000) NOT NULL,
  [HasQuotedHours] [bit] NOT NULL,
  [HasDescription] [bit] NOT NULL,
  [HasReference] [bit] NOT NULL,
  [IsCompulsory] [bit] NOT NULL,
  [IncludeStart] [bit] NOT NULL,
  [IncludeSchedule] [bit] NOT NULL,
  [IncludeDueDate] [bit] NOT NULL,
  [HasExternalSubmission] [bit] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_MilestoneTypes] on table [SMigration].[Onboarding_MilestoneTypes]')
GO
ALTER TABLE [SMigration].[Onboarding_MilestoneTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_MilestoneTypes] PRIMARY KEY CLUSTERED ([RunGuid], [MilestoneTypeGuid]) WITH (FILLFACTOR = 80)
GO