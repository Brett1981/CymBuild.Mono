CREATE TABLE [SCore].[EntityProperties] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityProperties_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityProperties_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityProperties_Name] DEFAULT (''),
  [LanguageLabelID] [int] NOT NULL CONSTRAINT [DF_EntityProperties_LanguageLabelID] DEFAULT (-1),
  [EntityHoBTID] [int] NOT NULL CONSTRAINT [DF_EntityProperties_EntityHoBTID] DEFAULT (-1),
  [EntityDataTypeID] [int] NOT NULL CONSTRAINT [DF_EntityProperties_EntityDateTypeID] DEFAULT (-1),
  [IsReadOnly] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsReadOnly] DEFAULT (0),
  [IsImmutable] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsImmutable] DEFAULT (0),
  [IsUppercase] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsUppercase] DEFAULT (0),
  [IsHidden] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsHidden] DEFAULT (0),
  [IsCompulsory] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsCompulsory] DEFAULT (0),
  [MaxLength] [int] NOT NULL CONSTRAINT [DF_EntityProperties_MaxLength] DEFAULT (0),
  [Precision] [int] NOT NULL CONSTRAINT [DF_EntityProperties_Precision] DEFAULT (0),
  [Scale] [int] NOT NULL CONSTRAINT [DF_EntityProperties_Scale] DEFAULT (0),
  [DoNotTrackChanges] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_DoNotTrackChanges] DEFAULT (0),
  [EntityPropertyGroupID] [int] NOT NULL CONSTRAINT [DF_EntityProperties_EntityPropertyGroupID] DEFAULT (-1),
  [SortOrder] [smallint] NOT NULL CONSTRAINT [DF_EntityProperties_SortOrder] DEFAULT (0),
  [GroupSortOrder] [smallint] NOT NULL CONSTRAINT [DF_EntityProperties_GroupSortOrder] DEFAULT (0),
  [IsObjectLabel] [bit] NOT NULL CONSTRAINT [DEFAULT_EntityProperties_IsObjectLabel] DEFAULT (0),
  [DropDownListDefinitionID] [int] NOT NULL CONSTRAINT [DF_EntityProperties_DropDownListDefinitionID] DEFAULT (-1),
  [IsParentRelationship] [bit] NOT NULL CONSTRAINT [DEFAULT_EntityProperties_IsParentRelationship] DEFAULT (0),
  [IsLongitude] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsLongitude] DEFAULT (0),
  [IsLatitude] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsLatitude] DEFAULT (0),
  [IsIncludedInformation] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsIncludedInformation] DEFAULT (0),
  [FixedDefaultValue] [nvarchar](50) NOT NULL CONSTRAINT [DF_EntityProperties_FixDefaultValue] DEFAULT (''),
  [SqlDefaultValueStatement] [nvarchar](4000) NOT NULL CONSTRAINT [DF_EntityProperties_SqlDefaultValueScript] DEFAULT (''),
  [AllowBulkChange] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_AllowBulkChange] DEFAULT (0),
  [IsVirtual] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsVirtual] DEFAULT (0),
  [ShowOnMobile] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_ShowOnMobile] DEFAULT (0),
  [IsAlwaysVisibleInGroup] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsAlwaysVisibleInGroup] DEFAULT (0),
  [IsAlwaysVisibleInGroup_Mobile] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsAlwaysVisibleInGroup_Mobile] DEFAULT (0),
  CONSTRAINT [PK_EntityProperties] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80) ON [METADATA]
)
ON [METADATA]
GO

CREATE INDEX [IX_HobtProperties]
  ON [SCore].[EntityProperties] ([EntityHoBTID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityProperties_Guid]
  ON [SCore].[EntityProperties] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityProperties_Hobt_Name]
  ON [SCore].[EntityProperties] ([EntityHoBTID], [Name], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[EntityProperties]
  ADD CONSTRAINT [FK_EntityProperties_DropDownListDefinitions] FOREIGN KEY ([DropDownListDefinitionID]) REFERENCES [SUserInterface].[DropDownListDefinitions] ([ID])
GO

ALTER TABLE [SCore].[EntityProperties]
  ADD CONSTRAINT [FK_EntityProperties_EntityDataTypes] FOREIGN KEY ([EntityDataTypeID]) REFERENCES [SCore].[EntityDataTypes] ([ID])
GO

ALTER TABLE [SCore].[EntityProperties]
  ADD CONSTRAINT [FK_EntityProperties_EntityHoBTs] FOREIGN KEY ([EntityHoBTID]) REFERENCES [SCore].[EntityHobts] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SCore].[EntityProperties]
  ADD CONSTRAINT [FK_EntityProperties_EntityPropertyGroupID] FOREIGN KEY ([EntityPropertyGroupID]) REFERENCES [SCore].[EntityPropertyGroups] ([ID])
GO

ALTER TABLE [SCore].[EntityProperties]
  ADD CONSTRAINT [FK_EntityProperties_LanguageLabels] FOREIGN KEY ([LanguageLabelID]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

ALTER TABLE [SCore].[EntityProperties]
  ADD CONSTRAINT [FK_EntityProperties_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'Describes the properties within each Entity Type and how they relate to the columns in the HoBT', 'SCHEMA', N'SCore', 'TABLE', N'EntityProperties'
GO