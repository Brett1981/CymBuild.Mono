CREATE TABLE [SSop].[QuoteMemos] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_QuoteMemos_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_QuoteMemos_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteID] [int] NOT NULL CONSTRAINT [DC_QuoteMemos_QuoteID] DEFAULT (-1),
  [Memo] [nvarchar](max) NOT NULL CONSTRAINT [DC_QuoteMemos_Memo] DEFAULT (''),
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DC_QuoteMemos_CreatedDateTimeUTC] DEFAULT (getutcdate()),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DC_QuoteMemos_CreatedByUserId] DEFAULT (-1),
  [LegacyId] [bigint] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  CONSTRAINT [PK_QuoteMemos_ID] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [IX_QuoteMemos_Quote]
  ON [SSop].[QuoteMemos] ([QuoteID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_QuoteMemos_Guid]
  ON [SSop].[QuoteMemos] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SSop].[QuoteMemos]
  ADD CONSTRAINT [FK_QuoteMemos_CreatedByUserId] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SSop].[QuoteMemos] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteMemos_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[QuoteMemos]
  NOCHECK CONSTRAINT [FK_QuoteMemos_Guid]
GO

ALTER TABLE [SSop].[QuoteMemos]
  ADD CONSTRAINT [FK_QuoteMemos_QuoteID] FOREIGN KEY ([QuoteID]) REFERENCES [SSop].[Quotes] ([ID])
GO

ALTER TABLE [SSop].[QuoteMemos]
  ADD CONSTRAINT [FK_QuoteMemos_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO