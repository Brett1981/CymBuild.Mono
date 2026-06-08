PRINT (N'Create table [SMigration].[Onboarding_ValidationIssues]')
GO
CREATE TABLE [SMigration].[Onboarding_ValidationIssues] (
  [ID] [bigint] IDENTITY,
  [RunGuid] [uniqueidentifier] NOT NULL,
  [EntityName] [nvarchar](200) NOT NULL,
  [StageTable] [nvarchar](200) NOT NULL,
  [StageGuid] [uniqueidentifier] NULL,
  [Severity] [nvarchar](20) NOT NULL,
  [IssueCode] [nvarchar](100) NOT NULL,
  [IssueMessage] [nvarchar](2000) NOT NULL,
  [CreatedUtc] [datetime2](3) NOT NULL CONSTRAINT [DF_SMigration_Onboarding_ValidationIssues_CreatedUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_ValidationIssues] on table [SMigration].[Onboarding_ValidationIssues]')
GO
ALTER TABLE [SMigration].[Onboarding_ValidationIssues] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_ValidationIssues] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_SMigration_Onboarding_ValidationIssues_RunGuid] on table [SMigration].[Onboarding_ValidationIssues]')
GO
CREATE INDEX [IX_SMigration_Onboarding_ValidationIssues_RunGuid]
  ON [SMigration].[Onboarding_ValidationIssues] ([RunGuid], [Severity], [EntityName], [IssueCode])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO