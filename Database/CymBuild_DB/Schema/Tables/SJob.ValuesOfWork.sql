CREATE TABLE [SJob].[ValuesOfWork] (
  [ID] [smallint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ValuesOfWork_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ValuesOfWork_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_ValuesOfWork_Name] DEFAULT (''),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_ValuesOfWork_SortOrder] DEFAULT (0),
  CONSTRAINT [PK_ValuesOfWork] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_ValuesOfWork_Guid]
  ON [SJob].[ValuesOfWork] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[ValuesOfWork] WITH NOCHECK
  ADD CONSTRAINT [FK_ValuesOfWork_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[ValuesOfWork]
  NOCHECK CONSTRAINT [FK_ValuesOfWork_DataObjects]
GO

ALTER TABLE [SJob].[ValuesOfWork]
  ADD CONSTRAINT [FK_ValuesOfWork_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO