CREATE TABLE [SJob].[JobPurposeGroups] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobPurposeGroups_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobPurposeGroups_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DF_JobPurposeGroups_JobID] DEFAULT (-1),
  [PurposeGroupID] [int] NOT NULL CONSTRAINT [DF_JobPurposeGroups_PurposeGroupID] DEFAULT (-1),
  CONSTRAINT [PK_JobPurposeGroups] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_JobPurposeGroups_JobId]
  ON [SJob].[JobPurposeGroups] ([JobID], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_JobPurposeGroups_Guid]
  ON [SJob].[JobPurposeGroups] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE STATISTICS [stat_JobPurposeGroups_Job_Guid]
  ON [SJob].[JobPurposeGroups] ([JobID], [Guid])
GO

ALTER TABLE [SJob].[JobPurposeGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPurposeGroups_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[JobPurposeGroups]
  NOCHECK CONSTRAINT [FK_JobPurposeGroups_DataObjects]
GO

ALTER TABLE [SJob].[JobPurposeGroups]
  ADD CONSTRAINT [FK_JobPurposeGroups_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SJob].[JobPurposeGroups]
  ADD CONSTRAINT [FK_JobPurposeGroups_PurposeGroups] FOREIGN KEY ([PurposeGroupID]) REFERENCES [SJob].[PurposeGroups] ([ID])
GO

ALTER TABLE [SJob].[JobPurposeGroups]
  ADD CONSTRAINT [FK_JobPurposeGroups_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO