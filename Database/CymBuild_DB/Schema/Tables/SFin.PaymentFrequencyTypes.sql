CREATE TABLE [SFin].[PaymentFrequencyTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_PaymentFrequencyTypes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_PaymentFrequencyTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_PaymentFrequencyTypes_Name] DEFAULT (''),
  CONSTRAINT [PK_PaymentFrequencyTypes] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_PaymentFrequency_Name]
  ON [SFin].[PaymentFrequencyTypes] ([Guid], [Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_PaymentFrequencyTypes_Guid]
  ON [SFin].[PaymentFrequencyTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SFin].[PaymentFrequencyTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_PaymentFrequencyTypes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SFin].[PaymentFrequencyTypes]
  NOCHECK CONSTRAINT [FK_PaymentFrequencyTypes_DataObjects]
GO

ALTER TABLE [SFin].[PaymentFrequencyTypes]
  ADD CONSTRAINT [FK_PaymentFrequencyTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO