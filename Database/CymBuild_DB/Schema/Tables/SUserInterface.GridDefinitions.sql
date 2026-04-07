PRINT (N'Create table [SUserInterface].[GridDefinitions]')
GO
CREATE TABLE [SUserInterface].[GridDefinitions] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_GridDefinition_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_GridDefinitions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Code] [nvarchar](30) NOT NULL CONSTRAINT [DF_GridDefinition_Code] DEFAULT (''),
  [PageUri] [nvarchar](250) NOT NULL CONSTRAINT [DF_GridDefinition_PageUri] DEFAULT (''),
  [TabName] [nvarchar](100) NOT NULL CONSTRAINT [DF_GridDefinition_TabName] DEFAULT (''),
  [ShowAsTiles] [bit] NOT NULL CONSTRAINT [DF_GridDefinition_ShowAsTiles] DEFAULT (0),
  [LanguageLabelId] [int] NOT NULL CONSTRAINT [DF__GridDefin__Langu__1D2FE27E] DEFAULT (-1)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_GridDefinitions] on table [SUserInterface].[GridDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridDefinitions] WITH NOCHECK
  ADD CONSTRAINT [PK_GridDefinitions] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_GridDefinition_Code] on table [SUserInterface].[GridDefinitions]')
GO
CREATE UNIQUE INDEX [IX_UQ_GridDefinition_Code]
  ON [SUserInterface].[GridDefinitions] ([Code], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_GridDefinition_Guid] on table [SUserInterface].[GridDefinitions]')
GO
CREATE UNIQUE INDEX [IX_UQ_GridDefinition_Guid]
  ON [SUserInterface].[GridDefinitions] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_GridDefinitions_LanguageLabelId] on table [SUserInterface].[GridDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridDefinitions_LanguageLabelId] FOREIGN KEY ([LanguageLabelId]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_GridDefinitions_RowStatus] on table [SUserInterface].[GridDefinitions]')
GO
ALTER TABLE [SUserInterface].[GridDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridDefinitions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SUserInterface].[GridDefinitions]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'The definition of Grid layouts that are the parent container of GridViewDefinitions', 'SCHEMA', N'SUserInterface', 'TABLE', N'GridDefinitions'
GO