PRINT (N'Create table [SMigration].[Onboarding_JobTypeActivityTypes]')
GO
CREATE TABLE [SMigration].[Onboarding_JobTypeActivityTypes] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [JobTypeActivityTypeGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [JobTypeGuid] [uniqueidentifier] NOT NULL,
  [ActivityTypeGuid] [uniqueidentifier] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_JTAT] on table [SMigration].[Onboarding_JobTypeActivityTypes]')
GO
ALTER TABLE [SMigration].[Onboarding_JobTypeActivityTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_JTAT] PRIMARY KEY CLUSTERED ([RunGuid], [JobTypeActivityTypeGuid]) WITH (FILLFACTOR = 80)
GO