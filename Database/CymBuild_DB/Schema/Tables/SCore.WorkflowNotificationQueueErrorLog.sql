PRINT (N'Create table [SCore].[WorkflowNotificationQueueErrorLog]')
GO
CREATE TABLE [SCore].[WorkflowNotificationQueueErrorLog] (
  [ID] [int] IDENTITY,
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_WNQEL_CreatedOnUtc] DEFAULT (sysutcdatetime()),
  [TriggerName] [sysname] NULL,
  [TransitionGuid] [uniqueidentifier] NULL,
  [StatusId] [int] NULL,
  [ErrorNumber] [int] NULL,
  [ErrorSeverity] [int] NULL,
  [ErrorState] [int] NULL,
  [ErrorLine] [int] NULL,
  [ErrorProcedure] [nvarchar](200) NULL,
  [ErrorMessage] [nvarchar](max) NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key on table [SCore].[WorkflowNotificationQueueErrorLog]')
GO
ALTER TABLE [SCore].[WorkflowNotificationQueueErrorLog] WITH NOCHECK
  ADD PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO