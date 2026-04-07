CREATE TABLE [SJob].[StagePaymentBatchItems] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_StagePaymentBatchItems_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_StagePaymentBatchItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [StagePaymentBatchId] [int] NOT NULL CONSTRAINT [DF_StagePaymentBatchItems_StagePaymentBatchId] DEFAULT (-1),
  [JobPaymentStageId] [int] NOT NULL CONSTRAINT [DF_StagePaymentBatchItems_JobPaymentStageId] DEFAULT (-1),
  CONSTRAINT [PK_StagePaymentBatchItems] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

ALTER TABLE [SJob].[StagePaymentBatchItems] WITH NOCHECK
  ADD CONSTRAINT [FK_StagePaymentBatchItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[StagePaymentBatchItems]
  NOCHECK CONSTRAINT [FK_StagePaymentBatchItems_DataObjects]
GO

ALTER TABLE [SJob].[StagePaymentBatchItems]
  ADD CONSTRAINT [FK_StagePaymentBatchItems_JobPaymentStages] FOREIGN KEY ([JobPaymentStageId]) REFERENCES [SJob].[JobPaymentStages] ([ID])
GO

ALTER TABLE [SJob].[StagePaymentBatchItems]
  ADD CONSTRAINT [FK_StagePaymentBatchItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SJob].[StagePaymentBatchItems]
  ADD CONSTRAINT [FK_StagePaymentBatchItems_StagePaymentBatch] FOREIGN KEY ([StagePaymentBatchId]) REFERENCES [SJob].[StagePaymentBatch] ([ID])
GO