CREATE TABLE [SJob].[ActionTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_ActionTypes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_ActionTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](150) NOT NULL CONSTRAINT [DC_ActionTypes_Name] DEFAULT (''),
  [IsActive] [bit] NOT NULL CONSTRAINT [DC_ActionTypes_IsActive] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DC_ActionTypes_SortOrder] DEFAULT (0),
  [Colour] [nvarchar](6) NOT NULL CONSTRAINT [DC_ActionTypes_Colour] DEFAULT (''),
  CONSTRAINT [PK_ActionTypes_ID] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ActionTypes_Guid]
  ON [SJob].[ActionTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ActionTypes_Name]
  ON [SJob].[ActionTypes] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[ActionTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_ActionTypes_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[ActionTypes]
  NOCHECK CONSTRAINT [FK_ActionTypes_Guid]
GO

ALTER TABLE [SJob].[ActionTypes]
  ADD CONSTRAINT [FK_ActionTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO