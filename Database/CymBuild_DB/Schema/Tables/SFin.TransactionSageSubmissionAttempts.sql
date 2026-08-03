PRINT (N'Create table [SFin].[TransactionSageSubmissionAttempts]')
GO
PRINT (N'Create table [SFin].[TransactionSageSubmissionAttempts]')
GO
CREATE TABLE [SFin].[TransactionSageSubmissionAttempts] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionAttempts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionAttempts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SubmissionStatusID] [bigint] NOT NULL,
  [TransactionID] [bigint] NOT NULL,
  [TransactionGuid] [uniqueidentifier] NOT NULL,
  [TransitionGuid] [uniqueidentifier] NOT NULL,
  [OperationName] [nvarchar](100) NOT NULL CONSTRAINT [DF_TransactionSageSubmissionAttempts_OperationName] DEFAULT (N'CreateSalesOrder'),
  [AttemptedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionAttempts_AttemptedOnUtc] DEFAULT (sysutcdatetime()),
  [CompletedOnUtc] [datetime2] NULL,
  [IsSuccess] [bit] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionAttempts_IsSuccess] DEFAULT (0),
  [IsRetryableFailure] [bit] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionAttempts_IsRetryableFailure] DEFAULT (0),
  [SageOrderId] [nvarchar](100) NULL,
  [SageOrderNumber] [nvarchar](100) NULL,
  [ResponseStatus] [nvarchar](50) NULL,
  [ResponseDetail] [nvarchar](max) NULL,
  [ErrorMessage] [nvarchar](max) NULL,
  [RequestPayloadJson] [nvarchar](max) NULL,
  [ResponsePayloadJson] [nvarchar](max) NULL,
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionAttempts_CreatedDateTimeUTC] DEFAULT (sysutcdatetime()),
  [CreatedByUserID] [int] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionAttempts_CreatedByUserID] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_TransactionSageSubmissionAttempts] on table [SFin].[TransactionSageSubmissionAttempts]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionAttempts] WITH NOCHECK
  ADD CONSTRAINT [PK_TransactionSageSubmissionAttempts] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_TransactionSageSubmissionAttempts_Guid] on table [SFin].[TransactionSageSubmissionAttempts]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionAttempts] WITH NOCHECK
  ADD CONSTRAINT [UQ_TransactionSageSubmissionAttempts_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_TransactionSageSubmissionAttempts_TransactionGuid_AttemptedOnUtc] on table [SFin].[TransactionSageSubmissionAttempts]')
GO
CREATE INDEX [IX_TransactionSageSubmissionAttempts_TransactionGuid_AttemptedOnUtc]
  ON [SFin].[TransactionSageSubmissionAttempts] ([TransactionGuid], [AttemptedOnUtc] DESC)
  INCLUDE ([TransitionGuid], [IsSuccess], [IsRetryableFailure], [SageOrderId], [SageOrderNumber], [ResponseStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_TransactionSageSubmissionAttempts_CreatedBy] on table [SFin].[TransactionSageSubmissionAttempts]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionAttempts] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionSageSubmissionAttempts_CreatedBy] FOREIGN KEY ([CreatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionSageSubmissionAttempts_DataObjects] on table [SFin].[TransactionSageSubmissionAttempts]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionAttempts] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionSageSubmissionAttempts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_TransactionSageSubmissionAttempts_DataObjects] on table [SFin].[TransactionSageSubmissionAttempts]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionAttempts]
  NOCHECK CONSTRAINT [FK_TransactionSageSubmissionAttempts_DataObjects]
GO

PRINT (N'Create foreign key [FK_TransactionSageSubmissionAttempts_RowStatus] on table [SFin].[TransactionSageSubmissionAttempts]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionAttempts] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionSageSubmissionAttempts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionSageSubmissionAttempts_Status] on table [SFin].[TransactionSageSubmissionAttempts]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionAttempts] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionSageSubmissionAttempts_Status] FOREIGN KEY ([SubmissionStatusID]) REFERENCES [SFin].[TransactionSageSubmissionStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionSageSubmissionAttempts_Transactions] on table [SFin].[TransactionSageSubmissionAttempts]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionAttempts] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionSageSubmissionAttempts_Transactions] FOREIGN KEY ([TransactionID]) REFERENCES [SFin].[Transactions] ([ID])
GO