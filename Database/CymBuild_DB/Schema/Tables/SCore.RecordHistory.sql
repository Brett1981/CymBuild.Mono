PRINT (N'Create table [SCore].[RecordHistory]')
GO
CREATE TABLE [SCore].[RecordHistory] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_RecordHistory_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowVersion] [timestamp],
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_RecordHistory_RowStatus] DEFAULT (0),
  [SchemaName] [nvarchar](250) NOT NULL CONSTRAINT [DF_RecordHistory_SchemaName] DEFAULT (''),
  [TableName] [nvarchar](250) NOT NULL CONSTRAINT [DF_RecordHistory_Table] DEFAULT (''),
  [ColumnName] [nvarchar](250) NOT NULL CONSTRAINT [DF_RecordHistory_ColumnName] DEFAULT (''),
  [RowID] [bigint] NOT NULL CONSTRAINT [DF_RecordHistory_RowID] DEFAULT (-1),
  [RowGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_RecordHistory_RowGuid] DEFAULT (newid()),
  [Datetime] [datetime] NOT NULL CONSTRAINT [DF_RecordHistory_Datetime] DEFAULT (getutcdate()),
  [UserID] [int] NOT NULL CONSTRAINT [DF_RecordHistory_UserID] DEFAULT (-1),
  [SQLUser] [nvarchar](250) NOT NULL CONSTRAINT [DF_RecordHistory_SQLUser] DEFAULT (''),
  [PreviousValue] [nvarchar](max) NOT NULL CONSTRAINT [DF_RecordHistory_PreviousValue] DEFAULT (''),
  [NewValue] [nvarchar](max) NOT NULL CONSTRAINT [DF_RecordHistory_NewValue] DEFAULT (''),
  [EntityPropertyID] [int] NOT NULL CONSTRAINT [DF_RecordHistory_EntityPropertyID] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_RecordHistory] on table [SCore].[RecordHistory]')
GO
ALTER TABLE [SCore].[RecordHistory] WITH NOCHECK
  ADD CONSTRAINT [PK_RecordHistory] PRIMARY KEY CLUSTERED ([ID]) WITH (PAD_INDEX = ON, FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_RecordHistory_Date] on table [SCore].[RecordHistory]')
GO
CREATE INDEX [IX_RecordHistory_Date]
  ON [SCore].[RecordHistory] ([Datetime])
  INCLUDE ([RowGuid])
  WITH (FILLFACTOR = 90, ALLOW_PAGE_LOCKS = OFF)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_RecordHistory_Guid] on table [SCore].[RecordHistory]')
GO
CREATE UNIQUE INDEX [IX_RecordHistory_Guid]
  ON [SCore].[RecordHistory] ([Guid])
  WITH (PAD_INDEX = ON, FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_RecordHistory_RowGuid] on table [SCore].[RecordHistory]')
GO
CREATE INDEX [IX_RecordHistory_RowGuid]
  ON [SCore].[RecordHistory] ([RowGuid])
  INCLUDE ([RowStatus], [Datetime])
  WITH (PAD_INDEX = ON, FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_RecordHistory_RowStatus] on table [SCore].[RecordHistory]')
GO
CREATE INDEX [IX_RecordHistory_RowStatus]
  ON [SCore].[RecordHistory] ([RowStatus])
  INCLUDE ([RowGuid], [Datetime])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_RecordHistory_EntityPropertyID] on table [SCore].[RecordHistory]')
GO
ALTER TABLE [SCore].[RecordHistory] WITH NOCHECK
  ADD CONSTRAINT [FK_RecordHistory_EntityPropertyID] FOREIGN KEY ([EntityPropertyID]) REFERENCES [SCore].[EntityProperties] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_RecordHistory_Identities] on table [SCore].[RecordHistory]')
GO
ALTER TABLE [SCore].[RecordHistory] WITH NOCHECK
  ADD CONSTRAINT [FK_RecordHistory_Identities] FOREIGN KEY ([UserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[RecordHistory]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'An audit of all changes made to user data. ', 'SCHEMA', N'SCore', 'TABLE', N'RecordHistory'
GO