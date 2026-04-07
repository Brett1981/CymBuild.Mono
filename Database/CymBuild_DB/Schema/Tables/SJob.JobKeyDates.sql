CREATE TABLE [SJob].[JobKeyDates] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_JobKeyDates_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_JobKeyDates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DC_JobKeyDates_JobID] DEFAULT (-1),
  [Detail] [nvarchar](500) NOT NULL DEFAULT (''),
  [DateTime] [datetime2] NULL,
  CONSTRAINT [PK_JobKeyDates_ID] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_JobPurposeGroups_JobId]
  ON [SJob].[JobKeyDates] ([JobID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_JobPurposeGroups_Guid]
  ON [SJob].[JobKeyDates] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[JobKeyDates] WITH NOCHECK
  ADD CONSTRAINT [FK_JobKeyDates_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[JobKeyDates]
  NOCHECK CONSTRAINT [FK_JobKeyDates_Guid]
GO

ALTER TABLE [SJob].[JobKeyDates]
  ADD CONSTRAINT [FK_JobKeyDates_JobID] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SJob].[JobKeyDates]
  ADD CONSTRAINT [FK_JobKeyDates_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO