CREATE TABLE [SCore].[EntityPropertyGroups] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityPropertyGroups_Name] DEFAULT (''),
  [IsHidden] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_IsHidden] DEFAULT (0),
  [SortOrder] [smallint] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_SortOrder] DEFAULT (0),
  [LanguageLabelID] [int] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_LanguageLabelID] DEFAULT (-1),
  [EntityTypeID] [int] NOT NULL CONSTRAINT [DEFAULT_EntityPropertyGroups_EntityTypeID] DEFAULT (-1),
  [PropertyGroupLayoutID] [int] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_PropertyGroupLayoutID] DEFAULT (-1),
  [ShowOnMobile] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_ShowOnMobile] DEFAULT (0),
  [IsCollapsable] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_IsCollapsable] DEFAULT (0),
  [IsDefaultCollapsed] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_IsDefaultCollapsed] DEFAULT (0),
  [IsDefaultCollapsed_Mobile] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_IsDefaultCollapsed_Moble] DEFAULT (0),
  CONSTRAINT [PK_EntityPropertyGroups] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityPropertyGroups_EntityTypeID_Name]
  ON [SCore].[EntityPropertyGroups] ([Name], [EntityTypeID])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityPropertyGroups_Guid]
  ON [SCore].[EntityPropertyGroups] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[EntityPropertyGroups]
  ADD CONSTRAINT [FK_EntityPropertyGroups_EntityTypes] FOREIGN KEY ([EntityTypeID]) REFERENCES [SCore].[EntityTypes] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SCore].[EntityPropertyGroups]
  ADD CONSTRAINT [FK_EntityPropertyGroups_LanguageLabels] FOREIGN KEY ([LanguageLabelID]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

ALTER TABLE [SCore].[EntityPropertyGroups]
  ADD CONSTRAINT [FK_EntityPropertyGroups_PropertyGroupLayouts] FOREIGN KEY ([PropertyGroupLayoutID]) REFERENCES [SUserInterface].[PropertyGroupLayouts] ([ID])
GO

ALTER TABLE [SCore].[EntityPropertyGroups]
  ADD CONSTRAINT [FK_EntityPropertyGroups_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'Records to group properties together', 'SCHEMA', N'SCore', 'TABLE', N'EntityPropertyGroups'
GO