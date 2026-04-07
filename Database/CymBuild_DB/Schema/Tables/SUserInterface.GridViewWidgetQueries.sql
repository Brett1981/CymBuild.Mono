CREATE TABLE [SUserInterface].[GridViewWidgetQueries] (
  [Id] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowVersion] [timestamp],
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_RowStatus] DEFAULT (0),
  [GridViewDefinitionId] [int] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_GridViewDefinitionId] DEFAULT (-1),
  [EntityQueryId] [int] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_EntityQueryId] DEFAULT (-1),
  [WidgetTypeId] [smallint] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_WidgetTypeId] DEFAULT (-1),
  [LanguageLabelID] [int] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_LanguageLabelID] DEFAULT (-1),
  CONSTRAINT [PK_GridViewWidgetQueries] PRIMARY KEY CLUSTERED ([Id]) ON [METADATA]
)
ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_GridViewWidgetQueries]
  ON [SUserInterface].[GridViewWidgetQueries] ([GridViewDefinitionId], [EntityQueryId], [WidgetTypeId])
  ON [METADATA]
GO

ALTER TABLE [SUserInterface].[GridViewWidgetQueries]
  ADD CONSTRAINT [FK_GridViewWidgetQueries_EntityQueries] FOREIGN KEY ([EntityQueryId]) REFERENCES [SCore].[EntityQueries] ([ID])
GO

ALTER TABLE [SUserInterface].[GridViewWidgetQueries]
  ADD CONSTRAINT [FK_GridViewWidgetQueries_GridViewDefinitions] FOREIGN KEY ([GridViewDefinitionId]) REFERENCES [SUserInterface].[GridViewDefinitions] ([ID])
GO

ALTER TABLE [SUserInterface].[GridViewWidgetQueries]
  ADD CONSTRAINT [FK_GridViewWidgetQueries_LanguageLabels] FOREIGN KEY ([LanguageLabelID]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

ALTER TABLE [SUserInterface].[GridViewWidgetQueries]
  ADD CONSTRAINT [FK_GridViewWidgetQueries_WidgetTypes] FOREIGN KEY ([WidgetTypeId]) REFERENCES [SUserInterface].[WidgetTypes] ([Id])
GO