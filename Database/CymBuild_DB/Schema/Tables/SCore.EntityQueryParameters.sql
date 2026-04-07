CREATE TABLE [SCore].[EntityQueryParameters] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityQueryParameters_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityQueryParameters_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityQueryParameters_Name] DEFAULT (''),
  [EntityQueryID] [int] NOT NULL CONSTRAINT [DF_EntityQueryParameters_EntityQueryID] DEFAULT (-1),
  [EntityDataTypeID] [int] NOT NULL CONSTRAINT [DF_EntityQueryParameters_EntityDateTypeID] DEFAULT (-1),
  [MappedEntityPropertyID] [int] NOT NULL CONSTRAINT [DF_EntityQueryParameters_EntityPropertyID] DEFAULT (-1),
  [DefaultValue] [nvarchar](100) NOT NULL CONSTRAINT [DF_EntityQueryParameters_DefaultValue] DEFAULT (''),
  [IsInput] [bit] NOT NULL CONSTRAINT [DF_EntityQueryParameters_IsInput] DEFAULT (0),
  [IsOutput] [bit] NOT NULL CONSTRAINT [DF_EntityQueryParameters_IsOutput] DEFAULT (0),
  [IsReturnColumn] [bit] NOT NULL CONSTRAINT [DF_EntityQueryParameters_IsReturnColumn] DEFAULT (0),
  CONSTRAINT [PK_EntityQueryParameters] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

CREATE INDEX [IX_EntityQueryParameters_Settings]
  ON [SCore].[EntityQueryParameters] ([EntityQueryID], [RowStatus])
  INCLUDE ([RowVersion], [Guid], [Name], [EntityDataTypeID], [MappedEntityPropertyID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityQueryParameters_Guid]
  ON [SCore].[EntityQueryParameters] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityQueryParameters_Name_EntityQueryID]
  ON [SCore].[EntityQueryParameters] ([Name], [EntityQueryID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[EntityQueryParameters] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityQueryParameters_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCore].[EntityQueryParameters]
  NOCHECK CONSTRAINT [FK_EntityQueryParameters_DataObjects]
GO

ALTER TABLE [SCore].[EntityQueryParameters]
  ADD CONSTRAINT [FK_EntityQueryParameters_EntityDataTypes] FOREIGN KEY ([EntityDataTypeID]) REFERENCES [SCore].[EntityDataTypes] ([ID])
GO

ALTER TABLE [SCore].[EntityQueryParameters]
  ADD CONSTRAINT [FK_EntityQueryParameters_EntityProperties] FOREIGN KEY ([MappedEntityPropertyID]) REFERENCES [SCore].[EntityProperties] ([ID])
GO

ALTER TABLE [SCore].[EntityQueryParameters]
  ADD CONSTRAINT [FK_EntityQueryParameters_EntityQueries] FOREIGN KEY ([EntityQueryID]) REFERENCES [SCore].[EntityQueries] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SCore].[EntityQueryParameters]
  ADD CONSTRAINT [FK_EntityQueryParameters_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'How to map the values of the Entity Properties to the Parameters of the Entity Query', 'SCHEMA', N'SCore', 'TABLE', N'EntityQueryParameters'
GO