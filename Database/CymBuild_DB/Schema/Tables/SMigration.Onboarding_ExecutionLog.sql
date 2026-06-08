PRINT (N'Create table [SMigration].[Onboarding_ExecutionLog]')
GO
CREATE TABLE [SMigration].[Onboarding_ExecutionLog] (
  [ID] [bigint] IDENTITY,
  [RunGuid] [uniqueidentifier] NOT NULL,
  [StepName] [nvarchar](200) NOT NULL,
  [EntityName] [nvarchar](200) NOT NULL,
  [ActionName] [nvarchar](50) NOT NULL,
  [AffectedCount] [int] NOT NULL CONSTRAINT [DF_SMigration_Onboarding_ExecutionLog_AffectedCount] DEFAULT (0),
  [Details] [nvarchar](2000) NOT NULL CONSTRAINT [DF_SMigration_Onboarding_ExecutionLog_Details] DEFAULT (N''),
  [LoggedUtc] [datetime2](3) NOT NULL CONSTRAINT [DF_SMigration_Onboarding_ExecutionLog_LoggedUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_ExecutionLog] on table [SMigration].[Onboarding_ExecutionLog]')
GO
ALTER TABLE [SMigration].[Onboarding_ExecutionLog] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_ExecutionLog] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_SMigration_Onboarding_ExecutionLog_RunGuid] on table [SMigration].[Onboarding_ExecutionLog]')
GO
CREATE INDEX [IX_SMigration_Onboarding_ExecutionLog_RunGuid]
  ON [SMigration].[Onboarding_ExecutionLog] ([RunGuid], [StepName], [EntityName], [ActionName])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO