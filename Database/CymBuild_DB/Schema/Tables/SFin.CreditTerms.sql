CREATE TABLE [SFin].[CreditTerms] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_CreditTerms_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_CreditTerms_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_CreditTerms_Name] DEFAULT (''),
  [DueDays] [int] NOT NULL CONSTRAINT [DF_CreditTerms_DueDays] DEFAULT (0),
  CONSTRAINT [PK_CreditTerms] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_CreditTerms_Guid]
  ON [SFin].[CreditTerms] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_CreditTerms_Name]
  ON [SFin].[CreditTerms] ([RowStatus], [Name])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

ALTER TABLE [SFin].[CreditTerms] WITH NOCHECK
  ADD CONSTRAINT [FK_CreditTerms_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SFin].[CreditTerms]
  NOCHECK CONSTRAINT [FK_CreditTerms_DataObjects]
GO

ALTER TABLE [SFin].[CreditTerms]
  ADD CONSTRAINT [FK_CreditTerms_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO