PRINT (N'Create table [SUserInterface].[GridViewColumnDefinitions]')
GO
CREATE TABLE [SUserInterface].[GridViewColumnDefinitions] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_GridViewColumnDefinition_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_GridViewColumnDefinitions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_GridViewColumnDefinition_Name] DEFAULT (''),
  [ColumnOrder] [int] NOT NULL CONSTRAINT [DF_GridViewColumnDefinition_order] DEFAULT (0),
  [GridViewDefinitionId] [int] NOT NULL CONSTRAINT [DF_GridViewColumnDefinition_GridViewDefinitionId] DEFAULT (-1),
  [IsPrimaryKey] [bit] NOT NULL CONSTRAINT [DF_GridViewColumnDefinition_IsPrimaryKey] DEFAULT (0),
  [IsHidden] [bit] NOT NULL CONSTRAINT [DF_GridViewColumnDefinition_IsHidden] DEFAULT (0),
  [IsFiltered] [bit] NOT NULL CONSTRAINT [DF_GridViewColumnDefinition_IsFiltered] DEFAULT (0),
  [IsCombo] [bit] NOT NULL CONSTRAINT [DF_GridViewColumnDefinition_IsCombo] DEFAULT (0),
  [IsLongitude] [bit] NOT NULL CONSTRAINT [DEFAULT_GridViewColumnDefinitions_IsLongitude] DEFAULT (0),
  [IsLatitude] [bit] NOT NULL CONSTRAINT [DEFAULT_GridViewColumnDefinitions_IsLatitude] DEFAULT (0),
  [DisplayFormat] [nvarchar](50) NOT NULL CONSTRAINT [DF_GridViewColumnDefinitions_DisplayFormat] DEFAULT (''),
  [Width] [nvarchar](10) NOT NULL CONSTRAINT [DF_GridViewColumnDefinitions_Width] DEFAULT (''),
  [LanguageLabelId] [int] NOT NULL CONSTRAINT [DF__GridViewC__Langu__21F4979B] DEFAULT (-1),
  [TopHeaderCategory] [nvarchar](50) NOT NULL CONSTRAINT [DF__GridViewC__TopHe__47C14215] DEFAULT (''),
  [TopHeaderCategoryOrder] [int] NOT NULL CONSTRAINT [DF__GridViewC__TopHe__48B5664E] DEFAULT (0)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_GridViewColumnDefinitions] on table [SUserInterface].[GridViewColumnDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] WITH NOCHECK
  ADD CONSTRAINT [PK_GridViewColumnDefinitions] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_GridViewColumnDefinitions_GridView] on table [SUserInterface].[GridViewColumnDefinitions]')
GO
CREATE INDEX [IX_GridViewColumnDefinitions_GridView]
  ON [SUserInterface].[GridViewColumnDefinitions] ([GridViewDefinitionId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_GridViewColumnDefinition_Guid] on table [SUserInterface].[GridViewColumnDefinitions]')
GO
CREATE UNIQUE INDEX [IX_UQ_GridViewColumnDefinition_Guid]
  ON [SUserInterface].[GridViewColumnDefinitions] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_GridViewColumndefinition_IsPrimaryKey] on table [SUserInterface].[GridViewColumnDefinitions]')
GO
CREATE UNIQUE INDEX [IX_UQ_GridViewColumndefinition_IsPrimaryKey]
  ON [SUserInterface].[GridViewColumnDefinitions] ([GridViewDefinitionId], [IsPrimaryKey])
  WHERE ([IsPrimaryKey]=(1))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_GridViewColumnDefinition_GridViewDefinition] on table [SUserInterface].[GridViewColumnDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewColumnDefinition_GridViewDefinition] FOREIGN KEY ([GridViewDefinitionId]) REFERENCES [SUserInterface].[GridViewDefinitions] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_GridViewColumnDefinitions_LanguageLabelId] on table [SUserInterface].[GridViewColumnDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewColumnDefinitions_LanguageLabelId] FOREIGN KEY ([LanguageLabelId]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_GridViewColumnDefinitions_RowStatus] on table [SUserInterface].[GridViewColumnDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewColumnDefinitions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SUserInterface].[GridViewColumnDefinitions]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'The definition of the columns that make up a Grid View', 'SCHEMA', N'SUserInterface', 'TABLE', N'GridViewColumnDefinitions'
GO