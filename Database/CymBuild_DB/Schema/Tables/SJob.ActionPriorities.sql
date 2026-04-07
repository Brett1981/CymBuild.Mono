CREATE TABLE [SJob].[ActionPriorities] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_ActionPriorities_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_ActionPriorities_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](150) NOT NULL CONSTRAINT [DC_ActionPriorities_Name] DEFAULT (''),
  [IsActive] [bit] NOT NULL CONSTRAINT [DC_ActionPriorities_IsActive] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DC_ActionPriorities_SortOrder] DEFAULT (0),
  [Colour] [nvarchar](6) NOT NULL CONSTRAINT [DC_ActionPriorities_Colour] DEFAULT (''),
  CONSTRAINT [PK_ActionPriorities_ID] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ActionPriorities_Guid]
  ON [SJob].[ActionPriorities] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ActionPriorities_Name]
  ON [SJob].[ActionPriorities] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[ActionPriorities] WITH NOCHECK
  ADD CONSTRAINT [FK_ActionPriorities_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[ActionPriorities]
  NOCHECK CONSTRAINT [FK_ActionPriorities_Guid]
GO

ALTER TABLE [SJob].[ActionPriorities]
  ADD CONSTRAINT [FK_ActionPriorities_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO