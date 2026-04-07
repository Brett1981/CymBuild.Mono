SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [SJob].[Milestones] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Milestones_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Milestones_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DF_Milestones_JobID] DEFAULT (-1),
  [QuoteLineID] [int] NOT NULL CONSTRAINT [DF_Milestones_QuoteID] DEFAULT (-1),
  [MilestoneTypeID] [int] NOT NULL CONSTRAINT [DF_Milestones_MilestoneTypeID] DEFAULT (-1),
  [Description] [nvarchar](500) NOT NULL CONSTRAINT [DF_Milestones_Description] DEFAULT (''),
  [StartDateTimeUTC] [datetime2] NULL,
  [DueDateTimeUTC] [datetime2] NULL,
  [ScheduledDateTimeUTC] [datetime2] NULL,
  [CompletedDateTimeUTC] [datetime2] NULL,
  [QuotedHours] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Milestones_QuotedHours] DEFAULT (0),
  [EstimatedRemainingHours] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Milestones_EstimatedRemainingHours] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_Milestones_SortOrder] DEFAULT (0),
  [StartedByUserId] [int] NOT NULL CONSTRAINT [DF_Milestones_StartedByUserId] DEFAULT (-1),
  [CompletedByUserId] [int] NOT NULL CONSTRAINT [DF_Milestones_CompletedByUserId] DEFAULT (-1),
  [IsNotApplicable] [bit] NOT NULL CONSTRAINT [DF_Milestones_IsNotApplicable] DEFAULT (0),
  [ReviewedDateTimeUTC] [datetime2] NULL,
  [ReviewerUserId] [int] NOT NULL CONSTRAINT [DF_Milestones_ReviewerUserId] DEFAULT (-1),
  [Reference] [nvarchar](250) NOT NULL CONSTRAINT [DF_Milestones_Reference] DEFAULT (''),
  [IsComplete] AS (case when [CompletedDateTimeUTC] IS NOT NULL OR [IsNotApplicable]=(1) then (1) else (0) end) PERSISTED NOT NULL,
  [SubmittedDateTimeUTC] [datetime2] NULL,
  [SubmittedBy] [int] NOT NULL CONSTRAINT [DF_Milestones_SubmittedBy] DEFAULT (-1),
  [SubmissionExpiryDate] [datetime2] NULL,
  CONSTRAINT [PK_Milestones] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_JobMilestones]
  ON [SJob].[Milestones] ([JobID], [SortOrder], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_JobMilestones_Job]
  ON [SJob].[Milestones] ([JobID], [RowStatus])
  INCLUDE ([MilestoneTypeID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_JobMilestones_Overdue]
  ON [SJob].[Milestones] ([JobID], [MilestoneTypeID], [DueDateTimeUTC], [ScheduledDateTimeUTC], [IsComplete], [RowStatus])
  WHERE ([Rowstatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_MilestoneMetric]
  ON [SJob].[Milestones] ([JobID], [SortOrder], [CompletedDateTimeUTC], [RowStatus])
  INCLUDE ([Description])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_Milestones_ActiveSubmissions]
  ON [SJob].[Milestones] ([SubmittedDateTimeUTC], [SubmissionExpiryDate], [RowStatus])
  INCLUDE ([MilestoneTypeID])
  WHERE ([SubmittedDateTimeUTC] IS NOT NULL AND [RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_Milestones_IsComplete]
  ON [SJob].[Milestones] ([IsComplete], [RowStatus])
  INCLUDE ([JobID], [MilestoneTypeID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_Milestones_Started]
  ON [SJob].[Milestones] ([JobID], [MilestoneTypeID], [StartDateTimeUTC], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [StartDateTimeUTC] IS NOT NULL)
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Milestones_Guid]
  ON [SJob].[Milestones] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[Milestones] WITH NOCHECK
  ADD CONSTRAINT [FK_Milestones_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[Milestones]
  NOCHECK CONSTRAINT [FK_Milestones_DataObjects]
GO

ALTER TABLE [SJob].[Milestones]
  ADD CONSTRAINT [FK_Milestones_Identities] FOREIGN KEY ([StartedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SJob].[Milestones]
  ADD CONSTRAINT [FK_Milestones_Identities1] FOREIGN KEY ([CompletedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SJob].[Milestones]
  ADD CONSTRAINT [FK_Milestones_Identities2] FOREIGN KEY ([ReviewerUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SJob].[Milestones]
  ADD CONSTRAINT [FK_Milestones_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SJob].[Milestones]
  ADD CONSTRAINT [FK_Milestones_MilestoneTypes] FOREIGN KEY ([MilestoneTypeID]) REFERENCES [SJob].[MilestoneTypes] ([ID])
GO

ALTER TABLE [SJob].[Milestones]
  ADD CONSTRAINT [FK_Milestones_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO