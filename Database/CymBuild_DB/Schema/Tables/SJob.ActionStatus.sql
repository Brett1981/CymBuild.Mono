CREATE TABLE [SJob].[ActionStatus] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_ActionStatus_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_ActionStatus_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](150) NOT NULL CONSTRAINT [DC_ActionStatus_Name] DEFAULT (''),
  [IsActive] [bit] NOT NULL CONSTRAINT [DC_ActionStatus_IsActive] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DC_ActionStatus_SortOrder] DEFAULT (0),
  [Colour] [nvarchar](6) NOT NULL CONSTRAINT [DC_ActionStatus_Colour] DEFAULT (''),
  [IsCompleteStatus] [bit] NOT NULL DEFAULT (0),
  CONSTRAINT [PK_ActionStatus_ID] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ActionStatus_Guid]
  ON [SJob].[ActionStatus] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ActionStatus_Name]
  ON [SJob].[ActionStatus] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[ActionStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_ActionStatus_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[ActionStatus]
  NOCHECK CONSTRAINT [FK_ActionStatus_Guid]
GO

ALTER TABLE [SJob].[ActionStatus]
  ADD CONSTRAINT [FK_ActionStatus_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO