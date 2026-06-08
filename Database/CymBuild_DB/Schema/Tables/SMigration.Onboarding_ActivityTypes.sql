PRINT (N'Create table [SMigration].[Onboarding_ActivityTypes]')
GO
CREATE TABLE [SMigration].[Onboarding_ActivityTypes] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [ActivityTypeGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [Name] [nvarchar](150) NOT NULL,
  [IsActive] [bit] NOT NULL,
  [SortOrder] [int] NOT NULL,
  [IsFeeTrigger] [bit] NOT NULL,
  [IsLiveTrigger] [bit] NOT NULL,
  [IsAdmin] [bit] NOT NULL,
  [IsScheduleItem] [bit] NOT NULL,
  [Colour] [nvarchar](6) NOT NULL,
  [IsMeeting] [bit] NOT NULL,
  [IsSiteVisit] [bit] NOT NULL,
  [IsBillable] [bit] NOT NULL,
  [IsCommencementTrigger] [bit] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_ActivityTypes] on table [SMigration].[Onboarding_ActivityTypes]')
GO
ALTER TABLE [SMigration].[Onboarding_ActivityTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_ActivityTypes] PRIMARY KEY CLUSTERED ([RunGuid], [ActivityTypeGuid]) WITH (FILLFACTOR = 80)
GO