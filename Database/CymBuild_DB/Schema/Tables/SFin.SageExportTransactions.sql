PRINT (N'Create table [SFin].[SageExportTransactions]')
GO
CREATE TABLE [SFin].[SageExportTransactions] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_SageExportTransactions_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_SageExportTransactions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SageExportID] [bigint] NOT NULL CONSTRAINT [DF_SageExportTransactions_SageExportID] DEFAULT (-1),
  [TransactionID] [bigint] NOT NULL CONSTRAINT [DF_SageExportTransactions_TransactionID] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SageExportTransactions] on table [SFin].[SageExportTransactions]')
GO
ALTER TABLE [SFin].[SageExportTransactions] WITH NOCHECK
  ADD CONSTRAINT [PK_SageExportTransactions] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_SageExportTransaction_TransactionId] on table [SFin].[SageExportTransactions]')
GO
CREATE INDEX [IX_SageExportTransaction_TransactionId]
  ON [SFin].[SageExportTransactions] ([TransactionID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_SageExportTransactions_RowStatus] on table [SFin].[SageExportTransactions]')
GO
ALTER TABLE [SFin].[SageExportTransactions] WITH NOCHECK
  ADD CONSTRAINT [FK_SageExportTransactions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_SageExportTransactions_SageExports] on table [SFin].[SageExportTransactions]')
GO
ALTER TABLE [SFin].[SageExportTransactions] WITH NOCHECK
  ADD CONSTRAINT [FK_SageExportTransactions_SageExports] FOREIGN KEY ([SageExportID]) REFERENCES [SFin].[SageExports] ([ID])
GO

PRINT (N'Create foreign key [FK_SageExportTransactions_Transactions] on table [SFin].[SageExportTransactions]')
GO
ALTER TABLE [SFin].[SageExportTransactions] WITH NOCHECK
  ADD CONSTRAINT [FK_SageExportTransactions_Transactions] FOREIGN KEY ([TransactionID]) REFERENCES [SFin].[Transactions] ([ID]) ON DELETE CASCADE
GO