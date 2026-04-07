PRINT (N'Create table [SUserInterface].[DropDownListDefinitions]')
GO
CREATE TABLE [SUserInterface].[DropDownListDefinitions] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_DropDownListDefinition_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_DropDownListDefinitions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Code] [nvarchar](20) NOT NULL CONSTRAINT [DF_DropDownListDefinition_Code] DEFAULT (''),
  [NameColumn] [nvarchar](254) NOT NULL CONSTRAINT [DF_DropDownListDefinition_NameColumn] DEFAULT (''),
  [ValueColumn] [nvarchar](254) NOT NULL CONSTRAINT [DF_DropDownListDefinition_ValueColumn] DEFAULT (''),
  [SqlQuery] [nvarchar](max) NOT NULL CONSTRAINT [DF_DropDownListDefinition_SqlQuery] DEFAULT (''),
  [DefaultSortColumnName] [nvarchar](254) NOT NULL CONSTRAINT [DF_DropDownListDefinition_DefaultSortColumnName] DEFAULT (N'ID'),
  [IsDefaultColumn] [nvarchar](254) NOT NULL CONSTRAINT [DF_DropDownListDefinition_IdDefaultColumn] DEFAULT (''),
  [DetailPageUrl] [nvarchar](250) NOT NULL CONSTRAINT [DF_DropDownListDefinitions_DetailPageUrl] DEFAULT (''),
  [IsDetailWindowed] [bit] NOT NULL CONSTRAINT [DF_DropDownListDefinitions_IsDetailWindowed] DEFAULT (0),
  [EntityTypeId] [int] NOT NULL CONSTRAINT [DF_DropDownListDefinitions_EntityTypeId] DEFAULT (-1),
  [InformationPageUrl] [nvarchar](250) NOT NULL CONSTRAINT [DF_DropDownListDefinitions_InformationPageUrl] DEFAULT (''),
  [GroupColumn] [nvarchar](254) NOT NULL CONSTRAINT [DF_DropDownListDefinitions_GroupColumn] DEFAULT (''),
  [ColourHexColumn] [nvarchar](7) NOT NULL CONSTRAINT [DF_DropDownListDefinitions_ColourHexColumn] DEFAULT ('#000000'),
  [ExternalSearchPageUrl] [nvarchar](250) NOT NULL CONSTRAINT [DF_DropDownListDefinitions_ExternalSearchPageUrl] DEFAULT ('')
)
ON [METADATA]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_DropDownListDefinitions] on table [SUserInterface].[DropDownListDefinitions]')
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] WITH NOCHECK
  ADD CONSTRAINT [PK_DropDownListDefinitions] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_DropDownListDefinition_Settings] on table [SUserInterface].[DropDownListDefinitions]')
GO
CREATE INDEX [IX_DropDownListDefinition_Settings]
  ON [SUserInterface].[DropDownListDefinitions] ([Guid], [RowStatus])
  INCLUDE ([NameColumn], [ValueColumn], [SqlQuery], [Code], [DefaultSortColumnName], [GroupColumn])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_DropDownListDefinition_Code] on table [SUserInterface].[DropDownListDefinitions]')
GO
CREATE UNIQUE INDEX [IX_UQ_DropDownListDefinition_Code]
  ON [SUserInterface].[DropDownListDefinitions] ([Code], [RowStatus])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_DropDownListDefinition_Guid] on table [SUserInterface].[DropDownListDefinitions]')
GO
CREATE UNIQUE INDEX [IX_UQ_DropDownListDefinition_Guid]
  ON [SUserInterface].[DropDownListDefinitions] ([Guid], [RowStatus])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

PRINT (N'Create foreign key [FK_DropDownListDefinitions_EntityTypes] on table [SUserInterface].[DropDownListDefinitions]')
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_DropDownListDefinitions_EntityTypes] FOREIGN KEY ([EntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_DropDownListDefinitions_RowStatus] on table [SUserInterface].[DropDownListDefinitions]')
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_DropDownListDefinitions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SUserInterface].[DropDownListDefinitions]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'The definition of how to display a drop down list. ', 'SCHEMA', N'SUserInterface', 'TABLE', N'DropDownListDefinitions'
GO