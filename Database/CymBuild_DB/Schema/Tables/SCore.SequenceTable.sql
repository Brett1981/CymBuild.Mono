PRINT (N'Create table [SCore].[SequenceTable]')
GO
PRINT (N'Create table [SCore].[SequenceTable]')
GO
CREATE TABLE [SCore].[SequenceTable] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_SequenceTable_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_SequenceTable_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SysName] [nvarchar](50) NOT NULL CONSTRAINT [DF_SequenceTable_SysName] DEFAULT (''),
  [FriendlyName] [nvarchar](50) NOT NULL CONSTRAINT [DF_SequenceTable_FriendlyName] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SequenceTable] on table [SCore].[SequenceTable]')
GO
ALTER TABLE [SCore].[SequenceTable] WITH NOCHECK
  ADD CONSTRAINT [PK_SequenceTable] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create index [IX_UQ_SequenceTable_FriendlyName] on table [SCore].[SequenceTable]')
GO
CREATE UNIQUE INDEX [IX_UQ_SequenceTable_FriendlyName]
  ON [SCore].[SequenceTable] ([FriendlyName])
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_SequenceTable_Guid] on table [SCore].[SequenceTable]')
GO
CREATE UNIQUE INDEX [IX_UQ_SequenceTable_Guid]
  ON [SCore].[SequenceTable] ([Guid])
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_SequenceTable_SysName] on table [SCore].[SequenceTable]')
GO
CREATE UNIQUE INDEX [IX_UQ_SequenceTable_SysName]
  ON [SCore].[SequenceTable] ([SysName])
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_SequenceTable_RowStatus] on table [SCore].[SequenceTable]')
GO
ALTER TABLE [SCore].[SequenceTable] WITH NOCHECK
  ADD CONSTRAINT [FK_SequenceTable_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO