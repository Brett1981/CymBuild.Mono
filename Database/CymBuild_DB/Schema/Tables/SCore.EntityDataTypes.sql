CREATE TABLE [SCore].[EntityDataTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityDataTypes_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityDataTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityDataTypes_Name] DEFAULT (''),
  [QuoteValue] [bit] NOT NULL CONSTRAINT [DF_EntityDataTypes_QuoteValue] DEFAULT (0),
  CONSTRAINT [PK_EntityDataTypes] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityDataTypes_Guid]
  ON [SCore].[EntityDataTypes] ([Guid], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_EntityDataTypes_Name]
  ON [SCore].[EntityDataTypes] ([Name])
  WHERE ([RowStatus]<>(0))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[EntityDataTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityDataTypes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCore].[EntityDataTypes]
  NOCHECK CONSTRAINT [FK_EntityDataTypes_DataObjects]
GO

ALTER TABLE [SCore].[EntityDataTypes]
  ADD CONSTRAINT [FK_EntityDataTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'Describes the type of data stored in an Entity Property', 'SCHEMA', N'SCore', 'TABLE', N'EntityDataTypes'
GO