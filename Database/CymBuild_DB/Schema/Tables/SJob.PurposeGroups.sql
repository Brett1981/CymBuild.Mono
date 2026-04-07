CREATE TABLE [SJob].[PurposeGroups] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_PurposeGroups_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_PurposeGroups_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](200) NOT NULL,
  CONSTRAINT [PK_PurposeGroups] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_JobPurposeGroups_Guid]
  ON [SJob].[PurposeGroups] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_PurposeGroups_Name]
  ON [SJob].[PurposeGroups] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[PurposeGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_PurposeGroups_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[PurposeGroups]
  NOCHECK CONSTRAINT [FK_PurposeGroups_DataObjects]
GO

ALTER TABLE [SJob].[PurposeGroups]
  ADD CONSTRAINT [FK_PurposeGroups_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO