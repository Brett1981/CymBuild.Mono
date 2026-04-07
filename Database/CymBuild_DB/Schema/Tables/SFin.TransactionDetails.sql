CREATE TABLE [SFin].[TransactionDetails] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_TransactionDetails_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_TransactionDetails_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [TransactionID] [bigint] NOT NULL CONSTRAINT [DF_TransactionDetails_TransactionID] DEFAULT (-1),
  [MilestoneID] [bigint] NOT NULL CONSTRAINT [DF_TransactionDetails_MilestoneID] DEFAULT (-1),
  [ActivityID] [bigint] NOT NULL CONSTRAINT [DF_TransactionDetails_ActivityID] DEFAULT (-1),
  [Net] [decimal](9, 2) NOT NULL CONSTRAINT [DF_TransactionDetails_Net] DEFAULT (0),
  [Vat] [decimal](9, 2) NOT NULL CONSTRAINT [DF_TransactionDetails_Vat] DEFAULT (0),
  [Gross] [decimal](9, 2) NOT NULL CONSTRAINT [DF_TransactionDetails_Gross] DEFAULT (0),
  [VatRate] [decimal](9, 2) NOT NULL CONSTRAINT [DF_TransactionDetails_VatRate] DEFAULT (0),
  [Description] [nvarchar](2000) NOT NULL CONSTRAINT [DF_TransactionDetails_Description] DEFAULT (''),
  [LegacyId] [decimal](18, 2) NULL,
  [JobPaymentStageId] [int] NOT NULL CONSTRAINT [DF_TransactionDetails_JobPaymentStageId] DEFAULT (-1),
  [InvoiceRequestItemId] [bigint] NOT NULL CONSTRAINT [DF_TransactionDetails_InvoiceRequestId] DEFAULT (-1),
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [RIBAStageId] [int] NOT NULL CONSTRAINT [DF_TransactionDetails_RIBAStageId] DEFAULT (-1),
  CONSTRAINT [PK_TransactionDetails] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_TransactionDetail_TransactionId]
  ON [SFin].[TransactionDetails] ([TransactionID], [RowStatus])
  INCLUDE ([Gross], [Net], [Vat])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE INDEX [IX_TransactionDetails_ActivityId]
  ON [SFin].[TransactionDetails] ([ActivityID], [RowStatus])
  INCLUDE ([Net], [TransactionID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE INDEX [IX_TransactionDetails_InvoiceRequestItem]
  ON [SFin].[TransactionDetails] ([InvoiceRequestItemId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_TransactionDetails_Guid]
  ON [SFin].[TransactionDetails] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SFin].[TransactionDetails]
  ADD CONSTRAINT [FK_TransactionDetails_Activities] FOREIGN KEY ([ActivityID]) REFERENCES [SJob].[Activities] ([ID])
GO

ALTER TABLE [SFin].[TransactionDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionDetails_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SFin].[TransactionDetails]
  NOCHECK CONSTRAINT [FK_TransactionDetails_DataObjects]
GO

ALTER TABLE [SFin].[TransactionDetails]
  ADD CONSTRAINT [FK_TransactionDetails_InvoiceRequestItems] FOREIGN KEY ([InvoiceRequestItemId]) REFERENCES [SFin].[InvoiceRequestItems] ([ID])
GO

ALTER TABLE [SFin].[TransactionDetails]
  ADD CONSTRAINT [FK_TransactionDetails_Milestones] FOREIGN KEY ([MilestoneID]) REFERENCES [SJob].[Milestones] ([ID])
GO

ALTER TABLE [SFin].[TransactionDetails]
  ADD CONSTRAINT [FK_TransactionDetails_RibaStages] FOREIGN KEY ([RIBAStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

ALTER TABLE [SFin].[TransactionDetails]
  ADD CONSTRAINT [FK_TransactionDetails_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SFin].[TransactionDetails]
  ADD CONSTRAINT [FK_TransactionDetails_TransactionDetails] FOREIGN KEY ([ID]) REFERENCES [SFin].[TransactionDetails] ([ID])
GO

ALTER TABLE [SFin].[TransactionDetails]
  ADD CONSTRAINT [FK_TransactionDetails_Transactions] FOREIGN KEY ([TransactionID]) REFERENCES [SFin].[Transactions] ([ID]) ON DELETE CASCADE
GO