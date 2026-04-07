CREATE TABLE [SUserInterface].[GridViewActions] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_GridViewActions_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_GridViewActions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [GridViewDefinitionId] [int] NOT NULL CONSTRAINT [DF_GridViewActions_GridViewDefinitionId] DEFAULT (-1),
  [LanguageLabelId] [int] NOT NULL DEFAULT (-1),
  [EntityQueryId] [int] NOT NULL CONSTRAINT [DF_GridViewActions_EntityQueryId] DEFAULT (-1),
  CONSTRAINT [PK_GridViewActions] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_GridViewActions_Unique]
  ON [SUserInterface].[GridViewActions] ([GridViewDefinitionId], [EntityQueryId])
  ON [METADATA]
GO

ALTER TABLE [SUserInterface].[GridViewActions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewActions_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SUserInterface].[GridViewActions]
  NOCHECK CONSTRAINT [FK_GridViewActions_DataObjects]
GO

ALTER TABLE [SUserInterface].[GridViewActions]
  ADD CONSTRAINT [FK_GridViewActions_EntityQueries] FOREIGN KEY ([EntityQueryId]) REFERENCES [SCore].[EntityQueries] ([ID])
GO

ALTER TABLE [SUserInterface].[GridViewActions]
  ADD CONSTRAINT [FK_GridViewActions_GridViewDefinition] FOREIGN KEY ([GridViewDefinitionId]) REFERENCES [SUserInterface].[GridViewDefinitions] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SUserInterface].[GridViewActions]
  ADD CONSTRAINT [FK_GridViewActions_LanguageLabelId] FOREIGN KEY ([LanguageLabelId]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

ALTER TABLE [SUserInterface].[GridViewActions]
  ADD CONSTRAINT [FK_GridViewActions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO