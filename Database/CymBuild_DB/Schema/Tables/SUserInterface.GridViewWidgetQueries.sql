PRINT (N'Create table [SUserInterface].[GridViewWidgetQueries]')
GO
CREATE TABLE [SUserInterface].[GridViewWidgetQueries] (
  [Id] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowVersion] [timestamp],
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_RowStatus] DEFAULT (0),
  [GridViewDefinitionId] [int] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_GridViewDefinitionId] DEFAULT (-1),
  [EntityQueryId] [int] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_EntityQueryId] DEFAULT (-1),
  [WidgetTypeId] [smallint] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_WidgetTypeId] DEFAULT (-1),
  [LanguageLabelID] [int] NOT NULL CONSTRAINT [DF_GridViewWidgetQueries_LanguageLabelID] DEFAULT (-1)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_GridViewWidgetQueries] on table [SUserInterface].[GridViewWidgetQueries]')
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] WITH NOCHECK
  ADD CONSTRAINT [PK_GridViewWidgetQueries] PRIMARY KEY CLUSTERED ([Id]) ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_GridViewWidgetQueries] on table [SUserInterface].[GridViewWidgetQueries]')
GO
CREATE UNIQUE INDEX [IX_UQ_GridViewWidgetQueries]
  ON [SUserInterface].[GridViewWidgetQueries] ([GridViewDefinitionId], [EntityQueryId], [WidgetTypeId])
  ON [METADATA]
GO

PRINT (N'Create foreign key [FK_GridViewWidgetQueries_EntityQueries] on table [SUserInterface].[GridViewWidgetQueries]')
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewWidgetQueries_EntityQueries] FOREIGN KEY ([EntityQueryId]) REFERENCES [SCore].[EntityQueries] ([ID])
GO

PRINT (N'Create foreign key [FK_GridViewWidgetQueries_GridViewDefinitions] on table [SUserInterface].[GridViewWidgetQueries]')
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewWidgetQueries_GridViewDefinitions] FOREIGN KEY ([GridViewDefinitionId]) REFERENCES [SUserInterface].[GridViewDefinitions] ([ID])
GO

PRINT (N'Create foreign key [FK_GridViewWidgetQueries_LanguageLabels] on table [SUserInterface].[GridViewWidgetQueries]')
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewWidgetQueries_LanguageLabels] FOREIGN KEY ([LanguageLabelID]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_GridViewWidgetQueries_WidgetTypes] on table [SUserInterface].[GridViewWidgetQueries]')
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewWidgetQueries_WidgetTypes] FOREIGN KEY ([WidgetTypeId]) REFERENCES [SUserInterface].[WidgetTypes] ([Id])
GO