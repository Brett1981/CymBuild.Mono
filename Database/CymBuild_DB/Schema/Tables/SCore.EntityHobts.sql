CREATE TABLE [SCore].[EntityHobts] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityHoBTs_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityHoBTs_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SchemaName] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityHoBTs_SchemaName] DEFAULT (''),
  [ObjectName] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityHoBTs_ObjectName] DEFAULT (''),
  [EntityTypeID] [int] NOT NULL CONSTRAINT [DF_EntityHoBTs_EntityTypeID] DEFAULT (-1),
  [ObjectType] [char](1) NOT NULL CONSTRAINT [DF_EntityHoBTs_ObjectType] DEFAULT (''),
  [IsMainHoBT] [bit] NOT NULL CONSTRAINT [DF_EntityHoBTs_IsMainHoBT] DEFAULT (0),
  [IsReadOnlyOffline] [bit] NOT NULL CONSTRAINT [DF_EntityHoBTs_IsReadOnlyOffline] DEFAULT (0),
  CONSTRAINT [PK_EntityHoBTs] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

CREATE INDEX [IX_EntityHobts_EntityTypeID]
  ON [SCore].[EntityHobts] ([EntityTypeID])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

CREATE INDEX [IX_EntityTypeHobts]
  ON [SCore].[EntityHobts] ([EntityTypeID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityHoBTs_Guid]
  ON [SCore].[EntityHobts] ([Guid], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityHobts_SchemaName_ObjectName]
  ON [SCore].[EntityHobts] ([SchemaName], [ObjectName], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[EntityHobts] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityHobts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCore].[EntityHobts]
  NOCHECK CONSTRAINT [FK_EntityHobts_DataObjects]
GO

ALTER TABLE [SCore].[EntityHobts]
  ADD CONSTRAINT [FK_EntityHoBTs_EntityTypes] FOREIGN KEY ([EntityTypeID]) REFERENCES [SCore].[EntityTypes] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SCore].[EntityHobts]
  ADD CONSTRAINT [FK_EntityHobts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'Describes the structural object used for hold the Entity Properties', 'SCHEMA', N'SCore', 'TABLE', N'EntityHobts'
GO