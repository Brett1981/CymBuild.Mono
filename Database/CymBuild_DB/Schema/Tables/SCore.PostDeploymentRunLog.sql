PRINT (N'Create table [SCore].[PostDeploymentRunLog]')
GO
CREATE TABLE [SCore].[PostDeploymentRunLog] (
  [ID] [int] IDENTITY,
  [RunGuid] [uniqueidentifier] NOT NULL,
  [StepName] [nvarchar](200) NOT NULL,
  [ObjectName] [nvarchar](517) NULL,
  [Severity] [nvarchar](20) NOT NULL,
  [Message] [nvarchar](max) NOT NULL,
  [ErrorNumber] [int] NULL,
  [ErrorSeverity] [int] NULL,
  [ErrorState] [int] NULL,
  [ErrorLine] [int] NULL,
  [ErrorProcedure] [sysname] NULL,
  [CreatedUtc] [datetime2] NOT NULL CONSTRAINT [DF_PostDeploymentRunLog_CreatedUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_PostDeploymentRunLog] on table [SCore].[PostDeploymentRunLog]')
GO
ALTER TABLE [SCore].[PostDeploymentRunLog] WITH NOCHECK
  ADD CONSTRAINT [PK_PostDeploymentRunLog] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_PostDeploymentRunLog_RunGuid] on table [SCore].[PostDeploymentRunLog]')
GO
CREATE INDEX [IX_PostDeploymentRunLog_RunGuid]
  ON [SCore].[PostDeploymentRunLog] ([RunGuid], [Severity], [ID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO