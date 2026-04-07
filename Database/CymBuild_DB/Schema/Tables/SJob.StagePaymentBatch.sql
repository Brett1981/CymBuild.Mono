CREATE TABLE [SJob].[StagePaymentBatch] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_StagePaymentBatch_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_StagePaymentBatch_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [InclusiveFromDate] [date] NULL,
  [InclusiveToDate] [date] NULL,
  [IsProcessed] [bit] NOT NULL CONSTRAINT [DF_StagePaymentBatch_IsProcessed] DEFAULT (0),
  CONSTRAINT [PK_StagePaymentBatch] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

ALTER TABLE [SJob].[StagePaymentBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_StagePaymentBatch_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[StagePaymentBatch]
  NOCHECK CONSTRAINT [FK_StagePaymentBatch_DataObjects]
GO

ALTER TABLE [SJob].[StagePaymentBatch]
  ADD CONSTRAINT [FK_StagePaymentBatch_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO