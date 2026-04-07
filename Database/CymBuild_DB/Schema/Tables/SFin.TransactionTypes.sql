PRINT (N'Create table [SFin].[TransactionTypes]')
GO
CREATE TABLE [SFin].[TransactionTypes] (
  [ID] [smallint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_TransactionTypes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_TransactionTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_TransactionTypes_Name] DEFAULT (''),
  [IsActive] [bit] NOT NULL CONSTRAINT [DF_TransactionTypes_IsActive] DEFAULT (1),
  [SequenceID] [int] NOT NULL CONSTRAINT [DF_TransactionTypes_SequenceID] DEFAULT (-1),
  [IsNegated] [bit] NOT NULL CONSTRAINT [DF_TransactionTypes_IsNegated] DEFAULT (0),
  [IsBank] [bit] NOT NULL CONSTRAINT [DF_TransactionTypes_IsBank] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_TransactionTypes] on table [SFin].[TransactionTypes]')
GO
ALTER TABLE [SFin].[TransactionTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_TransactionTypes] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

PRINT (N'Create index [IX_TransactionTypes_IsBank] on table [SFin].[TransactionTypes]')
GO
CREATE INDEX [IX_TransactionTypes_IsBank]
  ON [SFin].[TransactionTypes] ([IsBank])
  INCLUDE ([IsNegated])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_TransactionTypes_Guid] on table [SFin].[TransactionTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_TransactionTypes_Guid]
  ON [SFin].[TransactionTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_TransactionTypes_Name] on table [SFin].[TransactionTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_TransactionTypes_Name]
  ON [SFin].[TransactionTypes] ([Name])
  INCLUDE ([IsNegated])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_TransactionTypes_DataObjects] on table [SFin].[TransactionTypes]')
GO
ALTER TABLE [SFin].[TransactionTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionTypes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_TransactionTypes_DataObjects] on table [SFin].[TransactionTypes]')
GO
ALTER TABLE [SFin].[TransactionTypes]
  NOCHECK CONSTRAINT [FK_TransactionTypes_DataObjects]
GO

PRINT (N'Create foreign key [FK_TransactionTypes_RowStatus] on table [SFin].[TransactionTypes]')
GO
ALTER TABLE [SFin].[TransactionTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionTypes_SequenceTable] on table [SFin].[TransactionTypes]')
GO
ALTER TABLE [SFin].[TransactionTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionTypes_SequenceTable] FOREIGN KEY ([SequenceID]) REFERENCES [SCore].[SequenceTable] ([ID])
GO