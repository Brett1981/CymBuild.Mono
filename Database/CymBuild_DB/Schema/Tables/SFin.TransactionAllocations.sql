CREATE TABLE [SFin].[TransactionAllocations] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_TransactionAllocations_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_TransactionAllocations_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SourceTransactionID] [bigint] NOT NULL CONSTRAINT [DF_TransactionAllocations_TransactionTypeID] DEFAULT (-1),
  [TargetTransactionID] [bigint] NOT NULL CONSTRAINT [DF_TransactionAllocations_AccountID] DEFAULT (-1),
  [AllocatedAmount] [decimal](9, 2) NOT NULL CONSTRAINT [DF_TransactionAllocations_AllocatedAmount] DEFAULT (0),
  CONSTRAINT [PK_TransactionAllocations] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_TransactionAllocations_SourceTransactionId]
  ON [SFin].[TransactionAllocations] ([SourceTransactionID], [AllocatedAmount], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_TransactionAllocations_TargetTransactionId]
  ON [SFin].[TransactionAllocations] ([TargetTransactionID], [AllocatedAmount], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_TransactionAllocations_Guid]
  ON [SFin].[TransactionAllocations] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SFin].[TransactionAllocations] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionAllocations_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SFin].[TransactionAllocations]
  NOCHECK CONSTRAINT [FK_TransactionAllocations_DataObjects]
GO

ALTER TABLE [SFin].[TransactionAllocations]
  ADD CONSTRAINT [FK_TransactionAllocations_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SFin].[TransactionAllocations]
  ADD CONSTRAINT [FK_TransactionAllocations_Transactions] FOREIGN KEY ([SourceTransactionID]) REFERENCES [SFin].[Transactions] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SFin].[TransactionAllocations]
  ADD CONSTRAINT [FK_TransactionAllocations_Transactions1] FOREIGN KEY ([TargetTransactionID]) REFERENCES [SFin].[Transactions] ([ID])
GO