PRINT (N'Create table [SCore].[WorkflowNotificationQueueDisabledLog]')
GO
CREATE TABLE [SCore].[WorkflowNotificationQueueDisabledLog] (
  [ID] [int] IDENTITY,
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_WNQDL_CreatedOnUtc] DEFAULT (sysutcdatetime()),
  [TransitionGuid] [uniqueidentifier] NULL,
  [StatusId] [int] NULL,
  [DisabledValue] [int] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key on table [SCore].[WorkflowNotificationQueueDisabledLog]')
GO
ALTER TABLE [SCore].[WorkflowNotificationQueueDisabledLog] WITH NOCHECK
  ADD PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO