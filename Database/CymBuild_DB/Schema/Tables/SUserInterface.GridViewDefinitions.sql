PRINT (N'Create table [SUserInterface].[GridViewDefinitions]')
GO
CREATE TABLE [SUserInterface].[GridViewDefinitions] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_GridViewDefinition_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Code] [nvarchar](20) NOT NULL CONSTRAINT [DF_GridViewDefinition_Code] DEFAULT (''),
  [GridDefinitionId] [int] NOT NULL CONSTRAINT [DF_GridViewDefinition_GridDefinitionId] DEFAULT (-1),
  [DetailPageUri] [nvarchar](250) NOT NULL CONSTRAINT [DF_GridViewDefinition_DetailPageUri] DEFAULT (''),
  [SqlQuery] [nvarchar](max) NOT NULL CONSTRAINT [DF_GridViewDefinition_SqlQuery] DEFAULT (''),
  [DefaultSortColumnName] [nvarchar](250) NOT NULL CONSTRAINT [DF_GridViewDefinition_DefaultSortColumnName] DEFAULT (N'ID'),
  [SecurableCode] [nvarchar](20) NOT NULL CONSTRAINT [DF_GridViewDefinition_SecurableCode] DEFAULT (N''),
  [DisplayOrder] [int] NOT NULL CONSTRAINT [DF_GridViewDefinition_DisplayOrder] DEFAULT (0),
  [DisplayGroupName] [nvarchar](50) NOT NULL CONSTRAINT [DF_GridViewDefinition_DisplayGroupName] DEFAULT (N''),
  [MetricSqlQuery] [nvarchar](max) NOT NULL CONSTRAINT [DF_GridViewDefinition_TileSqlQuery] DEFAULT (N''),
  [ShowMetric] [bit] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_ShowMetric] DEFAULT (0),
  [IsDetailWindowed] [bit] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_IsDetailWindowed] DEFAULT (0),
  [EntityTypeID] [int] NOT NULL CONSTRAINT [DF_GridViewDefinitions_EntityTypeID] DEFAULT (-1),
  [MetricTypeID] [int] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricTypeID] DEFAULT (-1),
  [MetricMin] [int] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricMin] DEFAULT (0),
  [MetricMax] [int] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricMax] DEFAULT (0),
  [MetricMinorUnit] [int] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricMinorUnit] DEFAULT (0),
  [MetricMajorUnit] [int] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricMajorUnit] DEFAULT (0),
  [MetricStartAngle] [int] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricStartAngle] DEFAULT (0),
  [MetricEndAngle] [int] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricEndAngle] DEFAULT (0),
  [MetricReversed] [bit] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricReversed] DEFAULT (0),
  [MetricRange1Min] [decimal] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange1Min] DEFAULT (0),
  [MetricRange1Max] [decimal] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange1Max] DEFAULT (0),
  [MetricRange1ColourHex] [nvarchar](10) NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange1ColourHex] DEFAULT (''),
  [MetricRange2Min] [decimal] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange2Min] DEFAULT (0),
  [MetricRange2Max] [decimal] NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange2Max] DEFAULT (0),
  [MetricRange2ColourHex] [nvarchar](10) NOT NULL CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange2ColourHex] DEFAULT (''),
  [IsDefaultSortDescending] [bit] NOT NULL CONSTRAINT [DF_GridViewDefinitions_IsDefaultSortDescending] DEFAULT (0),
  [AllowNew] [bit] NOT NULL CONSTRAINT [DF_GridViewDefinitions_AllowNew] DEFAULT (0),
  [AllowExcelExport] [bit] NOT NULL CONSTRAINT [DF_GridViewDefinitions_AllowExcelExport] DEFAULT (0),
  [AllowPdfExport] [bit] NOT NULL CONSTRAINT [DF_GridViewDefinitions_AllowPdfExport] DEFAULT (0),
  [AllowCsvExport] [bit] NOT NULL CONSTRAINT [DF_GridViewDefinitions_AllowCsvExport] DEFAULT (0),
  [LanguageLabelId] [int] NOT NULL CONSTRAINT [DF_GridViewDefinitions_LanguageLabelId] DEFAULT (-1),
  [DrawerIconId] [int] NOT NULL CONSTRAINT [DF_GridViewDefinitions_DrawIconId] DEFAULT (-1),
  [GridViewTypeId] [int] NOT NULL CONSTRAINT [DF_GridViewDefinitions_GridViewTypeId] DEFAULT (-1),
  [AllowBulkChange] [bit] NOT NULL CONSTRAINT [DF_GridViewDefinitions_AllowBulkChange] DEFAULT (0),
  [ShowOnMobile] [bit] NOT NULL CONSTRAINT [DF_GridViewDefinitions_IsMobile] DEFAULT (0),
  [TreeListFirstOrderBy] [nvarchar](100) NOT NULL CONSTRAINT [DF_GridViewColumnDefinitions_TreeListFirstOrderBy] DEFAULT (''),
  [TreeListSecondOrderBy] [nvarchar](100) NOT NULL CONSTRAINT [DF_GridViewColumnDefinitions_TreeListSecondOrderBy] DEFAULT (''),
  [TreeListThirdOrderBy] [nvarchar](100) NOT NULL CONSTRAINT [DF_GridViewColumnDefinitions_TreeListThirdOrderBy] DEFAULT (''),
  [TreeListOrderBy] [nvarchar](100) NOT NULL CONSTRAINT [DF_GridViewColumnDefinitions_TreeListOrderBy] DEFAULT (''),
  [TreeListGroupBy] [nvarchar](100) NOT NULL CONSTRAINT [DF_GridViewColumnDefinitions_TreeListGroupBy] DEFAULT (''),
  [ShowOnDashboard] [bit] NOT NULL CONSTRAINT [DF_GridViewDefinitions_ShowOnDashboard] DEFAULT (0),
  [FilteredListCreatedOnColumn] [nvarchar](100) NOT NULL CONSTRAINT [DF__GridViewD__Filte__77E32648] DEFAULT (N''),
  [FilteredListRedStatusIndicatorTxt] [nvarchar](100) NOT NULL CONSTRAINT [DF__GridViewD__Filte__78D74A81] DEFAULT (N''),
  [FilteredListOrangeStatusIndicatorTxt] [nvarchar](100) NOT NULL CONSTRAINT [DF__GridViewD__Filte__79CB6EBA] DEFAULT (N''),
  [FilteredListGreenStatusIndicatorTxt] [nvarchar](100) NOT NULL CONSTRAINT [DF__GridViewD__Filte__7ABF92F3] DEFAULT (N''),
  [FilteredListGroupBy] [nvarchar](100) NOT NULL CONSTRAINT [DF__GridViewD__Filte__7BB3B72C] DEFAULT (N'')
)
ON [METADATA]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_GridViewDefinitions] on table [SUserInterface].[GridViewDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] WITH NOCHECK
  ADD CONSTRAINT [PK_GridViewDefinitions] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80) ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_GridViewDefinitions_Metrics] on table [SUserInterface].[GridViewDefinitions]')
GO
CREATE INDEX [IX_GridViewDefinitions_Metrics]
  ON [SUserInterface].[GridViewDefinitions] ([ShowMetric], [RowStatus])
  INCLUDE ([DisplayGroupName], [DisplayOrder], [GridDefinitionId], [Guid], [MetricReversed], [MetricSqlQuery], [MetricStartAngle], [MetricTypeID], [MetricRange1ColourHex], [MetricRange1Max], [MetricRange1Min], [MetricRange2ColourHex], [MetricRange2Max], [MetricRange2Min], [LanguageLabelId], [MetricEndAngle], [MetricMajorUnit], [MetricMax], [MetricMin], [MetricMinorUnit])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [ShowMetric]=(1))
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_GridViewDefinitions_Read] on table [SUserInterface].[GridViewDefinitions]')
GO
CREATE INDEX [IX_GridViewDefinitions_Read]
  ON [SUserInterface].[GridViewDefinitions] ([GridDefinitionId], [ID], [Code], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_GridViewDefinition_Code] on table [SUserInterface].[GridViewDefinitions]')
GO
CREATE UNIQUE INDEX [IX_UQ_GridViewDefinition_Code]
  ON [SUserInterface].[GridViewDefinitions] ([GridDefinitionId], [Code], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_GridViewDefinition_Guid] on table [SUserInterface].[GridViewDefinitions]')
GO
CREATE UNIQUE INDEX [IX_UQ_GridViewDefinition_Guid]
  ON [SUserInterface].[GridViewDefinitions] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_GridViewDefinition_SortOrder] on table [SUserInterface].[GridViewDefinitions]')
GO
CREATE UNIQUE INDEX [IX_UQ_GridViewDefinition_SortOrder]
  ON [SUserInterface].[GridViewDefinitions] ([DisplayOrder], [GridDefinitionId], [RowStatus])
  WHERE ([RowStatus]=(1) AND [DisplayOrder]<>(0))
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create foreign key [FK_GridViewDefinition_GridDefinition] on table [SUserInterface].[GridViewDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewDefinition_GridDefinition] FOREIGN KEY ([GridDefinitionId]) REFERENCES [SUserInterface].[GridDefinitions] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_GridViewDefinitions_DrawerIconId] on table [SUserInterface].[GridViewDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewDefinitions_DrawerIconId] FOREIGN KEY ([DrawerIconId]) REFERENCES [SUserInterface].[Icons] ([ID])
GO

PRINT (N'Create foreign key [FK_GridViewDefinitions_EntityTypes] on table [SUserInterface].[GridViewDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewDefinitions_EntityTypes] FOREIGN KEY ([EntityTypeID]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_GridViewDefinitions_LanguageLabelId] on table [SUserInterface].[GridViewDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewDefinitions_LanguageLabelId] FOREIGN KEY ([LanguageLabelId]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_GridViewDefinitions_MetricTypes] on table [SUserInterface].[GridViewDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewDefinitions_MetricTypes] FOREIGN KEY ([MetricTypeID]) REFERENCES [SUserInterface].[MetricTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_GridViewDefinitions_RowStatus] on table [SUserInterface].[GridViewDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewDefinitions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SUserInterface].[GridViewDefinitions]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'The definition of Grid Views, these are children of GridDefinitions and contain GridViewColumnDefinitions', 'SCHEMA', N'SUserInterface', 'TABLE', N'GridViewDefinitions'
GO