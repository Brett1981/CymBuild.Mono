PRINT (N'Create table [SCore].[ObjectSharePointFolder]')
GO
CREATE TABLE [SCore].[ObjectSharePointFolder] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ObjectSharePointFolder_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ObjectSharePointFolder_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ObjectGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ObjectSharePointFolder_RecordGuid] DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [SharepointSiteId] [int] NOT NULL CONSTRAINT [DF_ObjectSharePointFolder_SharepointSiteId] DEFAULT (-1),
  [FolderPath] [nvarchar](500) NOT NULL CONSTRAINT [DF_ObjectSharePointFolder_FolderPath] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_ObjectSharePointFolder] on table [SCore].[ObjectSharePointFolder]')
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] WITH NOCHECK
  ADD CONSTRAINT [PK_ObjectSharePointFolder] PRIMARY KEY CLUSTERED ([ID]) WITH (PAD_INDEX = ON, FILLFACTOR = 90)
GO

PRINT (N'Create index [IX_UQ_ObjectSharePointFolder_Guid] on table [SCore].[ObjectSharePointFolder]')
GO
CREATE UNIQUE INDEX [IX_UQ_ObjectSharePointFolder_Guid]
  ON [SCore].[ObjectSharePointFolder] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_ObjectSharePointFolder_ObjectGuid] on table [SCore].[ObjectSharePointFolder]')
GO
CREATE UNIQUE INDEX [IX_UQ_ObjectSharePointFolder_ObjectGuid]
  ON [SCore].[ObjectSharePointFolder] ([ObjectGuid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_ObjectSharePointFolder_DataObjects] on table [SCore].[ObjectSharePointFolder]')
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSharePointFolder_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_ObjectSharePointFolder_DataObjects] on table [SCore].[ObjectSharePointFolder]')
GO
ALTER TABLE [SCore].[ObjectSharePointFolder]
  NOCHECK CONSTRAINT [FK_ObjectSharePointFolder_DataObjects]
GO

PRINT (N'Create foreign key [FK_ObjectSharePointFolder_SharepointSites] on table [SCore].[ObjectSharePointFolder]')
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSharePointFolder_SharepointSites] FOREIGN KEY ([SharepointSiteId]) REFERENCES [SCore].[SharepointSites] ([ID])
GO