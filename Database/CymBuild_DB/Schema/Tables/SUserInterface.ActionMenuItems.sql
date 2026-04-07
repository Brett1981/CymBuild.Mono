CREATE TABLE [SUserInterface].[ActionMenuItems] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ActionMenuItems_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ActionMenuItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [LanguageLabelId] [int] NOT NULL CONSTRAINT [DF_ActionMenuItems_LanguageLabelId] DEFAULT (-1),
  [IconCss] [nvarchar](100) NOT NULL CONSTRAINT [DF_ActionMenuItems_IconCss] DEFAULT (''),
  [Type] [nvarchar](1) NOT NULL CONSTRAINT [DF_ActionMenuItems_Type] DEFAULT (''),
  [EntityTypeId] [int] NOT NULL CONSTRAINT [DF_ActionMenuItems_EntityTypeId] DEFAULT (-1),
  [EntityQueryId] [int] NOT NULL CONSTRAINT [DF_ActionMenuItems_EntityQueryId] DEFAULT (-1),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_ActionMenuItems_SortOrder] DEFAULT (0),
  [RedirectToTargetGuid] [bit] NOT NULL CONSTRAINT [DF_ActionMenuItems_RedirectToTargetGuid] DEFAULT (0),
  CONSTRAINT [PK_ActionMenuItems] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE INDEX [IX_ActionMenuItems_EntityTypeId]
  ON [SUserInterface].[ActionMenuItems] ([EntityTypeId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ActionMenuItems_Gud]
  ON [SUserInterface].[ActionMenuItems] ([Guid])
  ON [PRIMARY]
GO

ALTER TABLE [SUserInterface].[ActionMenuItems] WITH NOCHECK
  ADD CONSTRAINT [FK_ActionMenuItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SUserInterface].[ActionMenuItems]
  NOCHECK CONSTRAINT [FK_ActionMenuItems_DataObjects]
GO

ALTER TABLE [SUserInterface].[ActionMenuItems]
  ADD CONSTRAINT [FK_ActionMenuItems_EntityQueries] FOREIGN KEY ([EntityQueryId]) REFERENCES [SCore].[EntityQueries] ([ID])
GO

ALTER TABLE [SUserInterface].[ActionMenuItems]
  ADD CONSTRAINT [FK_ActionMenuItems_EntityTypes] FOREIGN KEY ([EntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

ALTER TABLE [SUserInterface].[ActionMenuItems]
  ADD CONSTRAINT [FK_ActionMenuItems_LanguageLabels] FOREIGN KEY ([LanguageLabelId]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

ALTER TABLE [SUserInterface].[ActionMenuItems]
  ADD CONSTRAINT [FK_ActionMenuItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'Definition of actions to display in the Tasks Menu for an Entity Type', 'SCHEMA', N'SUserInterface', 'TABLE', N'ActionMenuItems'
GO