CREATE TABLE [SFin].[SageExportTransactions] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_SageExportTransactions_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_SageExportTransactions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SageExportID] [bigint] NOT NULL CONSTRAINT [DF_SageExportTransactions_SageExportID] DEFAULT (-1),
  [TransactionID] [bigint] NOT NULL CONSTRAINT [DF_SageExportTransactions_TransactionID] DEFAULT (-1),
  CONSTRAINT [PK_SageExportTransactions] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_SageExportTransaction_TransactionId]
  ON [SFin].[SageExportTransactions] ([TransactionID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  ON [PRIMARY]
GO

CREATE INDEX [IX_SageExportTransactions_SageExport]
  ON [SFin].[SageExportTransactions] ([SageExportID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_SageExportTransactions_Guid]
  ON [SFin].[SageExportTransactions] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SFin].[SageExportTransactions]
  ADD CONSTRAINT [FK_SageExportTransactions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SFin].[SageExportTransactions]
  ADD CONSTRAINT [FK_SageExportTransactions_SageExports] FOREIGN KEY ([SageExportID]) REFERENCES [SFin].[SageExports] ([ID])
GO

ALTER TABLE [SFin].[SageExportTransactions]
  ADD CONSTRAINT [FK_SageExportTransactions_Transactions] FOREIGN KEY ([TransactionID]) REFERENCES [SFin].[Transactions] ([ID]) ON DELETE CASCADE
GO