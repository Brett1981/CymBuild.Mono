PRINT (N'Create table [SCore].[WorkflowNotificationQueue]')
GO
CREATE TABLE [SCore].[WorkflowNotificationQueue] (
  [ID] [bigint] IDENTITY,
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_WorkflowNotificationQueue_Created] DEFAULT (sysutcdatetime()),
  [TransitionGuid] [uniqueidentifier] NOT NULL,
  [StatusId] [int] NOT NULL,
  [ProcessedOnUtc] [datetime2] NULL,
  [AttemptCount] [int] NOT NULL CONSTRAINT [DF_WorkflowNotificationQueue_Attempt] DEFAULT (0),
  [LastError] [nvarchar](2000) NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_WorkflowNotificationQueue] on table [SCore].[WorkflowNotificationQueue]')
GO
ALTER TABLE [SCore].[WorkflowNotificationQueue] WITH NOCHECK
  ADD CONSTRAINT [PK_WorkflowNotificationQueue] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_WorkflowNotificationQueue_Unprocessed] on table [SCore].[WorkflowNotificationQueue]')
GO
CREATE INDEX [IX_WorkflowNotificationQueue_Unprocessed]
  ON [SCore].[WorkflowNotificationQueue] ([ProcessedOnUtc], [CreatedOnUtc])
  INCLUDE ([StatusId], [AttemptCount])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [UX_WorkflowNotificationQueue_TransitionGuid] on table [SCore].[WorkflowNotificationQueue]')
GO
CREATE UNIQUE INDEX [UX_WorkflowNotificationQueue_TransitionGuid]
  ON [SCore].[WorkflowNotificationQueue] ([TransitionGuid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO