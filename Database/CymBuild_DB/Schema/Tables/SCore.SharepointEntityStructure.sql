PRINT (N'Create table [SCore].[SharepointEntityStructure]')
GO
PRINT (N'Create table [SCore].[SharepointEntityStructure]')
GO
CREATE TABLE [SCore].[SharepointEntityStructure] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_SharepointEntityStructure_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_SharepointEntityStructure_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SharePointSiteID] [int] NOT NULL CONSTRAINT [DF_SharepointEntityStructure_SharePointSiteID] DEFAULT (-1),
  [ParentStructureID] [int] NOT NULL CONSTRAINT [DF_SharepointEntityStructure_ParentStructureID] DEFAULT (-1),
  [EntityTypeID] [int] NOT NULL CONSTRAINT [DF_SharepointEntityStructure_EntityTypeID] DEFAULT (-1),
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_SharepointEntityStructure_Name] DEFAULT (''),
  [UseLibraryPerSplit] [bit] NOT NULL CONSTRAINT [DF_SharepointEntityStructure_IsLibrary] DEFAULT (0),
  [PrimaryKeySplitInterval] [int] NOT NULL CONSTRAINT [DF_SharepointEntityStructure_PrimaryKeySplitInterval] DEFAULT (0),
  [StartPrimaryKey] [bigint] NOT NULL CONSTRAINT [DF_SharepointEntityStructure_StartPrimaryKey] DEFAULT (0),
  [EndPrimaryKey] [bigint] NOT NULL CONSTRAINT [DF_SharepointEntityStructure_EndPrimaryKey] DEFAULT (0)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_SharepointEntityStructure] on table [SCore].[SharepointEntityStructure]')
GO
ALTER TABLE [SCore].[SharepointEntityStructure] WITH NOCHECK
  ADD CONSTRAINT [PK_SharepointEntityStructure] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_SharePointEntityStructure_Guid] on table [SCore].[SharepointEntityStructure]')
GO
CREATE UNIQUE INDEX [IX_UQ_SharePointEntityStructure_Guid]
  ON [SCore].[SharepointEntityStructure] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_SharepointEntityStructure_Site_Parent_Name] on table [SCore].[SharepointEntityStructure]')
GO
CREATE UNIQUE INDEX [IX_UQ_SharepointEntityStructure_Site_Parent_Name]
  ON [SCore].[SharepointEntityStructure] ([SharePointSiteID], [ParentStructureID], [Name])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_SharepointEntityStructure_EntityTypes] on table [SCore].[SharepointEntityStructure]')
GO
ALTER TABLE [SCore].[SharepointEntityStructure] WITH NOCHECK
  ADD CONSTRAINT [FK_SharepointEntityStructure_EntityTypes] FOREIGN KEY ([EntityTypeID]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_SharepointEntityStructure_RowStatus] on table [SCore].[SharepointEntityStructure]')
GO
ALTER TABLE [SCore].[SharepointEntityStructure] WITH NOCHECK
  ADD CONSTRAINT [FK_SharepointEntityStructure_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_SharepointEntityStructure_SharepointEntityStructure] on table [SCore].[SharepointEntityStructure]')
GO
ALTER TABLE [SCore].[SharepointEntityStructure] WITH NOCHECK
  ADD CONSTRAINT [FK_SharepointEntityStructure_SharepointEntityStructure] FOREIGN KEY ([ParentStructureID]) REFERENCES [SCore].[SharepointEntityStructure] ([ID])
GO

PRINT (N'Create foreign key [FK_SharepointEntityStructure_SharepointSites] on table [SCore].[SharepointEntityStructure]')
GO
ALTER TABLE [SCore].[SharepointEntityStructure] WITH NOCHECK
  ADD CONSTRAINT [FK_SharepointEntityStructure_SharepointSites] FOREIGN KEY ([SharePointSiteID]) REFERENCES [SCore].[SharepointSites] ([ID]) ON DELETE CASCADE
GO