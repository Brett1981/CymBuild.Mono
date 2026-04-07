CREATE TABLE [SCore].[EntityPropertyDependants] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EEntityPropertyDependants_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EEntityPropertyDependants_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ParentEntityPropertyID] [int] NOT NULL CONSTRAINT [DF_EEntityPropertyDependants_ParentEntityPropertyID] DEFAULT (-1),
  [DependantPropertyID] [int] NOT NULL CONSTRAINT [DF_EEntityPropertyDependants_DependentEntityPropertyID] DEFAULT (-1),
  CONSTRAINT [PK_EntityPropertyDependants] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityPropertyDependants_Guid]
  ON [SCore].[EntityPropertyDependants] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityPropertyDependants_Parent_Dependant]
  ON [SCore].[EntityPropertyDependants] ([ParentEntityPropertyID], [DependantPropertyID])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[EntityPropertyDependants]
  ADD CONSTRAINT [FK_EntityPropertyDependants_EntityProperties] FOREIGN KEY ([ParentEntityPropertyID]) REFERENCES [SCore].[EntityProperties] ([ID])
GO

ALTER TABLE [SCore].[EntityPropertyDependants]
  ADD CONSTRAINT [FK_EntityPropertyDependants_EntityProperties1] FOREIGN KEY ([DependantPropertyID]) REFERENCES [SCore].[EntityProperties] ([ID])
GO

ALTER TABLE [SCore].[EntityPropertyDependants]
  ADD CONSTRAINT [FK_EntityPropertyDependants_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'When the parent property changes, which properties should be rebound?', 'SCHEMA', N'SCore', 'TABLE', N'EntityPropertyDependants'
GO