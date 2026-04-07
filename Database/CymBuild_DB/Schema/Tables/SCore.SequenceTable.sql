CREATE TABLE [SCore].[SequenceTable] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_SequenceTable_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_SequenceTable_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SysName] [nvarchar](50) NOT NULL CONSTRAINT [DF_SequenceTable_SysName] DEFAULT (''),
  [FriendlyName] [nvarchar](50) NOT NULL CONSTRAINT [DF_SequenceTable_FriendlyName] DEFAULT (''),
  CONSTRAINT [PK_SequenceTable] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_SequenceTable_FriendlyName]
  ON [SCore].[SequenceTable] ([FriendlyName])
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_SequenceTable_Guid]
  ON [SCore].[SequenceTable] ([Guid])
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_SequenceTable_SysName]
  ON [SCore].[SequenceTable] ([SysName])
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[SequenceTable]
  ADD CONSTRAINT [FK_SequenceTable_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO