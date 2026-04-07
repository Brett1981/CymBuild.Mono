CREATE TABLE [SSop].[QuotePaymentStages] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuotePaymentStages_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuotePaymentStages_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteId] [int] NOT NULL CONSTRAINT [DF_QuotePaymentStages_QuoteId] DEFAULT (-1),
  [PaymentFrequencyTypeId] [int] NOT NULL CONSTRAINT [DF_QuotePaymentStages_PaymentFrequencyTypeId] DEFAULT (-1),
  [PaymentFrequency] [int] NOT NULL CONSTRAINT [DF_QuotePaymentStages_PaymentFrequency] DEFAULT (0),
  [Value] [decimal](18, 2) NOT NULL CONSTRAINT [DF_QuotePaymentStages_Value] DEFAULT (0),
  [PercentageOfTotal] [decimal](5, 2) NOT NULL CONSTRAINT [DF_QuotePaymentStages_PercentageOfTotal] DEFAULT (0),
  [PayAfterStageId] [int] NOT NULL CONSTRAINT [DF_QuotePaymentStages_PayAfterStageId] DEFAULT (-1),
  CONSTRAINT [PK_QuotePaymentStages] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE INDEX [IX_QuotePaymentStages_Quote]
  ON [SSop].[QuotePaymentStages] ([RowStatus], [QuoteId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_QuotePaymentStages_Guid]
  ON [SSop].[QuotePaymentStages] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SSop].[QuotePaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_QuotePaymentStages_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[QuotePaymentStages]
  NOCHECK CONSTRAINT [FK_QuotePaymentStages_DataObjects]
GO

ALTER TABLE [SSop].[QuotePaymentStages]
  ADD CONSTRAINT [FK_QuotePaymentStages_PaymentFrequencyTypes] FOREIGN KEY ([PaymentFrequencyTypeId]) REFERENCES [SFin].[PaymentFrequencyTypes] ([ID])
GO

ALTER TABLE [SSop].[QuotePaymentStages]
  ADD CONSTRAINT [FK_QuotePaymentStages_Quotes] FOREIGN KEY ([QuoteId]) REFERENCES [SSop].[Quotes] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SSop].[QuotePaymentStages]
  ADD CONSTRAINT [FK_QuotePaymentStages_RibaStages] FOREIGN KEY ([PayAfterStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

ALTER TABLE [SSop].[QuotePaymentStages]
  ADD CONSTRAINT [FK_QuotePaymentStages_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO