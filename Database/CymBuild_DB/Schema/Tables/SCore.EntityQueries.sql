CREATE TABLE [SCore].[EntityQueries] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityQueries_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityQuerues_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityQueries_Name] DEFAULT (''),
  [Statement] [nvarchar](max) NOT NULL CONSTRAINT [DF_EntityQueries_Statement] DEFAULT (''),
  [EntityTypeID] [int] NOT NULL CONSTRAINT [DF_EntityQueries_EntityTypeID] DEFAULT (-1),
  [EntityHoBTID] [int] NOT NULL CONSTRAINT [DEFAULT_EntityQueries_EnityHoBTID] DEFAULT (-1),
  [IsDefaultCreate] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsDefaultCreate] DEFAULT (0),
  [IsDefaultRead] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsDefaultRead] DEFAULT (0),
  [IsDefaultUpdate] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsDefaultUpdate] DEFAULT (0),
  [IsDefaultDelete] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsDefaultDelete] DEFAULT (0),
  [IsScalarExecute] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsScalarExecute] DEFAULT (0),
  [IsDefaultValidation] [bit] NOT NULL CONSTRAINT [DEFAULT_EntityQueries_IsDefaultValidation] DEFAULT (0),
  [UsesProcessGuid] [bit] NOT NULL CONSTRAINT [DEFAULT_EntityQueries_UsesProcessGuid] DEFAULT (0),
  [IsDefaultDataPills] [bit] NOT NULL CONSTRAINT [DEFAULT_EntityQueries_IsDefaultDataPills] DEFAULT (0),
  [IsProgressData] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsProgressData] DEFAULT (0),
  [IsMergeDocumentQuery] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsMergeDocumentQuery] DEFAULT (0),
  [SchemaName] [nvarchar](255) NOT NULL CONSTRAINT [DF_EntityQueries_SchemaName] DEFAULT (''),
  [ObjectName] [nvarchar](255) NOT NULL CONSTRAINT [DF_EntityQueries_ObjectName] DEFAULT (''),
  [IsManualStatement] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsManualStatement] DEFAULT (0),
  CONSTRAINT [PK_EntityQueries] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80) ON [METADATA]
)
ON [METADATA]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [IX_EntityQueries_EntityTypeID]
  ON [SCore].[EntityQueries] ([EntityTypeID], [RowStatus])
  INCLUDE ([RowVersion], [Guid], [Name], [EntityHoBTID], [IsDefaultCreate], [IsDefaultRead], [IsDefaultUpdate], [IsDefaultDelete], [IsProgressData], [Statement], [IsScalarExecute], [IsDefaultValidation], [IsDefaultDataPills])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityQueries_EntityHobtID_IsDefaultCreate]
  ON [SCore].[EntityQueries] ([EntityTypeID], [EntityHoBTID], [IsDefaultCreate], [RowStatus])
  WHERE ([IsDefaultCreate]=(1) AND [RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityQueries_EntityHobtID_IsDefaultDelete]
  ON [SCore].[EntityQueries] ([EntityTypeID], [EntityHoBTID], [IsDefaultDelete], [RowStatus])
  WHERE ([IsDefaultDelete]=(1) AND [RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityQueries_EntityHobtID_IsDefaultUpdate]
  ON [SCore].[EntityQueries] ([EntityTypeID], [EntityHoBTID], [IsDefaultUpdate], [RowStatus])
  WHERE ([IsDefaultUpdate]=(1) AND [RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityQueries_EntityHobtID_IsDefaultValidation]
  ON [SCore].[EntityQueries] ([EntityHoBTID], [IsDefaultValidation], [EntityTypeID])
  WHERE ([IsDefaultValidation]=(1))
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityQueries_Guid]
  ON [SCore].[EntityQueries] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityQueries_Name_EntityTypeID]
  ON [SCore].[EntityQueries] ([Name], [EntityTypeID], [EntityHoBTID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

ALTER TABLE [SCore].[EntityQueries] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityQueries_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCore].[EntityQueries]
  NOCHECK CONSTRAINT [FK_EntityQueries_DataObjects]
GO

ALTER TABLE [SCore].[EntityQueries]
  ADD CONSTRAINT [FK_EntityQueries_EntityHoBTs] FOREIGN KEY ([EntityHoBTID]) REFERENCES [SCore].[EntityHobts] ([ID])
GO

ALTER TABLE [SCore].[EntityQueries]
  ADD CONSTRAINT [FK_EntityQueries_EntityTypes] FOREIGN KEY ([EntityTypeID]) REFERENCES [SCore].[EntityTypes] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SCore].[EntityQueries]
  ADD CONSTRAINT [FK_EntityQueries_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'The queries to run in SQL to perform different functions on this Entity Type e.g. Create Read Update Delete Validate', 'SCHEMA', N'SCore', 'TABLE', N'EntityQueries'
GO