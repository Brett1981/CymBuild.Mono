PRINT (N'Create table [SCore].[EntityTypes]')
GO
CREATE TABLE [SCore].[EntityTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityTypes_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityTypes_Name] DEFAULT (''),
  [IsReadOnlyOffline] [bit] NOT NULL CONSTRAINT [DF_EntityTypes_IsReadOnlyOffline] DEFAULT (0),
  [IsRequiredSystemData] [bit] NOT NULL CONSTRAINT [DF_EntityTypes_IsRequiredSystemData] DEFAULT (0),
  [HasDocuments] [bit] NOT NULL CONSTRAINT [DF_EntityTypes_HasDocuments] DEFAULT (0),
  [LanguageLabelID] [int] NOT NULL CONSTRAINT [DF_EntityTypes_LanguageLabelID] DEFAULT (-1),
  [DoNotTrackChanges] [bit] NOT NULL CONSTRAINT [DF_Entities_DoNotTrackChanges] DEFAULT (0),
  [IsRootEntity] [bit] NOT NULL CONSTRAINT [DF_EntityTypes_IsRootEntity] DEFAULT (0),
  [DetailPageUrl] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityTypes_DetailPageUrl] DEFAULT (''),
  [IconId] [int] NOT NULL CONSTRAINT [DF__EntityTyp__IconI__10CA0B99] DEFAULT (-1),
  [IsMetaData] [bit] NOT NULL CONSTRAINT [DF_EntityTypes_IsMetaData] DEFAULT (0)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_EntityTypes] on table [SCore].[EntityTypes]')
GO
ALTER TABLE [SCore].[EntityTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_EntityTypes] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_EntityTypes_Get] on table [SCore].[EntityTypes]')
GO
CREATE INDEX [IX_EntityTypes_Get]
  ON [SCore].[EntityTypes] ([Guid])
  INCLUDE ([RowStatus], [RowVersion], [Name], [HasDocuments], [LanguageLabelID], [IconId])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_EntityTypes_Guid] on table [SCore].[EntityTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_EntityTypes_Guid]
  ON [SCore].[EntityTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_EntityTypes_Name] on table [SCore].[EntityTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_EntityTypes_Name]
  ON [SCore].[EntityTypes] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_EntityTypes_IconId] on table [SCore].[EntityTypes]')
GO
ALTER TABLE [SCore].[EntityTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityTypes_IconId] FOREIGN KEY ([IconId]) REFERENCES [SUserInterface].[Icons] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityTypes_LanguageLabels] on table [SCore].[EntityTypes]')
GO
ALTER TABLE [SCore].[EntityTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityTypes_LanguageLabels] FOREIGN KEY ([LanguageLabelID]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityTypes_RowStatus] on table [SCore].[EntityTypes]')
GO
ALTER TABLE [SCore].[EntityTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[EntityTypes]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'The definition of a thing in the system e.g. Job or Quote.', 'SCHEMA', N'SCore', 'TABLE', N'EntityTypes'
GO