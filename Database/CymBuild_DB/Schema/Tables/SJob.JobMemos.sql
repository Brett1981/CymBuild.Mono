CREATE TABLE [SJob].[JobMemos] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobMemos_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobMemos_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DF_JobMemos_JobID] DEFAULT (-1),
  [Memo] [nvarchar](max) NOT NULL CONSTRAINT [DF_JobMemos_Memo] DEFAULT (''),
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_JobMemos_CreatedDateTime] DEFAULT (getutcdate()),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_JobMemos_CreatedByUserId] DEFAULT (-1),
  [LegacyId] [bigint] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  CONSTRAINT [PK_JobMemos] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [Ix_JobMemos]
  ON [SJob].[JobMemos] ([JobID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_JobMemos_Guid]
  ON [SJob].[JobMemos] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[JobMemos] WITH NOCHECK
  ADD CONSTRAINT [FK_JobMemos_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[JobMemos]
  NOCHECK CONSTRAINT [FK_JobMemos_DataObjects]
GO

ALTER TABLE [SJob].[JobMemos]
  ADD CONSTRAINT [FK_JobMemos_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SJob].[JobMemos]
  ADD CONSTRAINT [FK_JobMemos_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SJob].[JobMemos]
  ADD CONSTRAINT [FK_JobMemos_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO