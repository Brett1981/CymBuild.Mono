CREATE TABLE [SJob].[ActivityStatus] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ActivityStatus_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ActivityStatus_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](150) NOT NULL CONSTRAINT [DF_ActivityStatus_Name] DEFAULT (''),
  [IsActive] [bit] NOT NULL CONSTRAINT [DF_ActivityStatus_IsActive] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_ActivityStatuss_SortOrder] DEFAULT (0),
  [IsCompleteStatus] [bit] NOT NULL CONSTRAINT [DF_ActivityStatus_IsCompleteStatus] DEFAULT (0),
  [Colour] [nvarchar](50) NOT NULL CONSTRAINT [DEFAULT_ActivityStatus_Colour] DEFAULT (''),
  CONSTRAINT [PK_ActivityStatus] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_ActivityStatus_Complete]
  ON [SJob].[ActivityStatus] ([IsCompleteStatus])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ActivityStatus_Guid]
  ON [SJob].[ActivityStatus] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ActivityStatus_Name]
  ON [SJob].[ActivityStatus] ([RowStatus], [Name])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[ActivityStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_ActivityStatus_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[ActivityStatus]
  NOCHECK CONSTRAINT [FK_ActivityStatus_DataObjects]
GO

ALTER TABLE [SJob].[ActivityStatus]
  ADD CONSTRAINT [FK_ActivityStatus_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO