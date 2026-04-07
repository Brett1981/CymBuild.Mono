PRINT (N'Create table [SCore].[RecentItems]')
GO
CREATE TABLE [SCore].[RecentItems] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_RecentItems_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_RecentItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Datetime] [datetime2] NOT NULL CONSTRAINT [DF_RecentItems_Datetime] DEFAULT (getutcdate()),
  [UserID] [int] NOT NULL CONSTRAINT [DF_RecentItems_UserID] DEFAULT (-1),
  [EntityTypeID] [int] NOT NULL CONSTRAINT [DF_RecentItems_EntityTypeID] DEFAULT (-1),
  [RecordGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_RecentItems_RecordGuid] DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [Label] [nvarchar](100) NOT NULL CONSTRAINT [DF_RecentItems_Label] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_RecentItems] on table [SCore].[RecentItems]')
GO
ALTER TABLE [SCore].[RecentItems] WITH NOCHECK
  ADD CONSTRAINT [PK_RecentItems] PRIMARY KEY CLUSTERED ([ID]) WITH (PAD_INDEX = ON, FILLFACTOR = 90)
GO

PRINT (N'Create index [IX_RecentItems_Record] on table [SCore].[RecentItems]')
GO
CREATE INDEX [IX_RecentItems_Record]
  ON [SCore].[RecentItems] ([UserID], [RowStatus])
  INCLUDE ([RowVersion], [Guid], [Datetime], [EntityTypeID], [RecordGuid], [Label])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_RecentItems_DataObjects] on table [SCore].[RecentItems]')
GO
ALTER TABLE [SCore].[RecentItems] WITH NOCHECK
  ADD CONSTRAINT [FK_RecentItems_DataObjects] FOREIGN KEY ([RecordGuid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_RecentItems_DataObjects] on table [SCore].[RecentItems]')
GO
ALTER TABLE [SCore].[RecentItems]
  NOCHECK CONSTRAINT [FK_RecentItems_DataObjects]
GO

PRINT (N'Create foreign key [FK_RecentItems_EntityTypes] on table [SCore].[RecentItems]')
GO
ALTER TABLE [SCore].[RecentItems] WITH NOCHECK
  ADD CONSTRAINT [FK_RecentItems_EntityTypes] FOREIGN KEY ([EntityTypeID]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_RecentItems_Identities] on table [SCore].[RecentItems]')
GO
ALTER TABLE [SCore].[RecentItems] WITH NOCHECK
  ADD CONSTRAINT [FK_RecentItems_Identities] FOREIGN KEY ([UserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[RecentItems]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'A log of which items each user has opened. ', 'SCHEMA', N'SCore', 'TABLE', N'RecentItems'
GO