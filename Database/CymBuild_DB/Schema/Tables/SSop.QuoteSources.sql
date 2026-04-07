CREATE TABLE [SSop].[QuoteSources] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuoteSources_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_QuoteSources_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_QuoteSources_Name] DEFAULT (''),
  CONSTRAINT [PK_QuoteSources] PRIMARY KEY CLUSTERED ([ID]),
  CONSTRAINT [UQ__QuoteSources_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 100)
)
ON [PRIMARY]
GO

ALTER TABLE [SSop].[QuoteSources] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSources_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[QuoteSources]
  NOCHECK CONSTRAINT [FK_QuoteSources_DataObjects]
GO

ALTER TABLE [SSop].[QuoteSources]
  ADD CONSTRAINT [FK_QuoteSources_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO