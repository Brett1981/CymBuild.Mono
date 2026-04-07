CREATE TABLE [SCore].[EntityPropertyActions] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityPropertyActions_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityPropertyActions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [EntityPropertyID] [int] NOT NULL CONSTRAINT [DF_EntityPropertyActions_EntityPropertyID] DEFAULT (-1),
  [Statement] [nvarchar](4000) NOT NULL CONSTRAINT [DF_EntityPropertyActions_Statement] DEFAULT (''),
  CONSTRAINT [PK_EntityPropertyActions] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

CREATE INDEX [IX_EntityPropertyActions_EntityProperty]
  ON [SCore].[EntityPropertyActions] ([EntityPropertyID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityPropertyActions_Guid]
  ON [SCore].[EntityPropertyActions] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

ALTER TABLE [SCore].[EntityPropertyActions]
  ADD CONSTRAINT [FK_EntityPropertyActions_EntityProperties] FOREIGN KEY ([EntityPropertyID]) REFERENCES [SCore].[EntityProperties] ([ID])
GO

ALTER TABLE [SCore].[EntityPropertyActions]
  ADD CONSTRAINT [FK_EntityPropertyActions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO