CREATE TABLE [SSop].[QuoteKeyDates] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_QuoteKeyDates_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_QuoteKeyDates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteId] [int] NOT NULL CONSTRAINT [DC_QuoteKeyDates_QuoteId] DEFAULT (-1),
  [Detail] [varchar](500) NOT NULL DEFAULT (''),
  [DateTime] [datetime2] NULL,
  CONSTRAINT [PK_QuoteKeyDates_ID] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE INDEX [IX_QuoteKeyDates_QuoteId]
  ON [SSop].[QuoteKeyDates] ([QuoteId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_QuoteKeyDates_Guid]
  ON [SSop].[QuoteKeyDates] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SSop].[QuoteKeyDates] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteKeyDates_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[QuoteKeyDates]
  NOCHECK CONSTRAINT [FK_QuoteKeyDates_Guid]
GO

ALTER TABLE [SSop].[QuoteKeyDates]
  ADD CONSTRAINT [FK_QuoteKeyDates_QuoteId] FOREIGN KEY ([QuoteId]) REFERENCES [SSop].[Quotes] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SSop].[QuoteKeyDates]
  ADD CONSTRAINT [FK_QuoteKeyDates_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO