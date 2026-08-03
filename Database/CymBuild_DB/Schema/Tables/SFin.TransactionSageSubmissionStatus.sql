PRINT (N'Create table [SFin].[TransactionSageSubmissionStatus]')
GO
PRINT (N'Create table [SFin].[TransactionSageSubmissionStatus]')
GO
CREATE TABLE [SFin].[TransactionSageSubmissionStatus] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionStatus_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionStatus_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [TransactionID] [bigint] NOT NULL,
  [TransactionGuid] [uniqueidentifier] NOT NULL,
  [LastTransitionGuid] [uniqueidentifier] NULL,
  [LastOperationName] [nvarchar](100) NOT NULL CONSTRAINT [DF_TransactionSageSubmissionStatus_LastOperationName] DEFAULT (N'CreateSalesOrder'),
  [StatusCode] [nvarchar](30) NOT NULL CONSTRAINT [DF_TransactionSageSubmissionStatus_StatusCode] DEFAULT (N'Pending'),
  [IsInProgress] [bit] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionStatus_IsInProgress] DEFAULT (0),
  [InProgressClaimedOnUtc] [datetime2] NULL,
  [LastSucceededOnUtc] [datetime2] NULL,
  [LastFailedOnUtc] [datetime2] NULL,
  [SageOrderId] [nvarchar](100) NULL,
  [SageOrderNumber] [nvarchar](100) NULL,
  [LastError] [nvarchar](max) NULL,
  [LastErrorIsRetryable] [bit] NULL,
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionStatus_CreatedDateTimeUTC] DEFAULT (sysutcdatetime()),
  [CreatedByUserID] [int] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionStatus_CreatedByUserID] DEFAULT (-1),
  [UpdatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionStatus_UpdatedDateTimeUTC] DEFAULT (sysutcdatetime()),
  [UpdatedByUserID] [int] NOT NULL CONSTRAINT [DF_TransactionSageSubmissionStatus_UpdatedByUserID] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_TransactionSageSubmissionStatus] on table [SFin].[TransactionSageSubmissionStatus]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionStatus] WITH NOCHECK
  ADD CONSTRAINT [PK_TransactionSageSubmissionStatus] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_TransactionSageSubmissionStatus_Guid] on table [SFin].[TransactionSageSubmissionStatus]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionStatus] WITH NOCHECK
  ADD CONSTRAINT [UQ_TransactionSageSubmissionStatus_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_TransactionSageSubmissionStatus_StatusCode] on table [SFin].[TransactionSageSubmissionStatus]')
GO
CREATE INDEX [IX_TransactionSageSubmissionStatus_StatusCode]
  ON [SFin].[TransactionSageSubmissionStatus] ([StatusCode], [IsInProgress])
  INCLUDE ([TransactionGuid], [SageOrderId], [SageOrderNumber], [LastSucceededOnUtc], [LastFailedOnUtc])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_TransactionSageSubmissionStatus_TransactionGuid_Active] on table [SFin].[TransactionSageSubmissionStatus]')
GO
CREATE UNIQUE INDEX [UX_TransactionSageSubmissionStatus_TransactionGuid_Active]
  ON [SFin].[TransactionSageSubmissionStatus] ([TransactionGuid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_TransactionSageSubmissionStatus_CreatedBy] on table [SFin].[TransactionSageSubmissionStatus]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionSageSubmissionStatus_CreatedBy] FOREIGN KEY ([CreatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionSageSubmissionStatus_DataObjects] on table [SFin].[TransactionSageSubmissionStatus]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionSageSubmissionStatus_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_TransactionSageSubmissionStatus_DataObjects] on table [SFin].[TransactionSageSubmissionStatus]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionStatus]
  NOCHECK CONSTRAINT [FK_TransactionSageSubmissionStatus_DataObjects]
GO

PRINT (N'Create foreign key [FK_TransactionSageSubmissionStatus_RowStatus] on table [SFin].[TransactionSageSubmissionStatus]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionSageSubmissionStatus_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionSageSubmissionStatus_Transactions] on table [SFin].[TransactionSageSubmissionStatus]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionSageSubmissionStatus_Transactions] FOREIGN KEY ([TransactionID]) REFERENCES [SFin].[Transactions] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionSageSubmissionStatus_UpdatedBy] on table [SFin].[TransactionSageSubmissionStatus]')
GO
ALTER TABLE [SFin].[TransactionSageSubmissionStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionSageSubmissionStatus_UpdatedBy] FOREIGN KEY ([UpdatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO