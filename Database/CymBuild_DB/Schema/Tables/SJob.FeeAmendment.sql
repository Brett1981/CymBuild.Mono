CREATE TABLE [SJob].[FeeAmendment] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_FeeAmendment_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_FeeAmendment_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DEFAULT_FeeAmendment_JobID] DEFAULT (-1),
  [CreatedByUserID] [int] NOT NULL CONSTRAINT [DEFAULT_FeeAmendment_CreatedByUserID] DEFAULT (-1),
  [CreatedDateTime] [datetime2] NOT NULL CONSTRAINT [DF_FeeAmendment_CreatedDateTime] DEFAULT (getutcdate()),
  [RibaStage0Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage0Change] DEFAULT (0),
  [RibaStage1Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage1Change] DEFAULT (0),
  [RibaStage2Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage2Change] DEFAULT (0),
  [RibaStage3Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage3Change] DEFAULT (0),
  [RibaStage4Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage4Change] DEFAULT (0),
  [RibaStage5Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage5Change] DEFAULT (0),
  [RibaStage6Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage6Change] DEFAULT (0),
  [RibaStage7Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage7Change] DEFAULT (0),
  [FeeCapChange] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_FeeCapChange] DEFAULT (0),
  [PreConstructionStageChange] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_PreConstructionStageChange] DEFAULT (0),
  [ConstructionStageChange] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_ConstructionStageChange] DEFAULT (0),
  [RibaStage0MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage0VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage1MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage1VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage2MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage2VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage3MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage3VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage4MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage4VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage5MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage5VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage6MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage6VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage7MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage7VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [PreConstructionStageMeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0),
  [PreConstructionStageVisitChange] [decimal](9, 2) NOT NULL DEFAULT (0),
  [ConstructionStageMeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0),
  [ConstructionStageVisitChange] [decimal](9, 2) NOT NULL DEFAULT (0),
  [Reason] [nvarchar](max) NOT NULL CONSTRAINT [DF_FeeAmendment_Reason] DEFAULT (N''),
  CONSTRAINT [PK_FeeAmendment] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [Ix_FeeAmendment_JobId]
  ON [SJob].[FeeAmendment] ([JobID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_FeeAmendments_Guid]
  ON [SJob].[FeeAmendment] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[FeeAmendment] WITH NOCHECK
  ADD CONSTRAINT [FK_FeeAmendment_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[FeeAmendment]
  NOCHECK CONSTRAINT [FK_FeeAmendment_DataObjects]
GO

ALTER TABLE [SJob].[FeeAmendment]
  ADD CONSTRAINT [FK_FeeAmendment_Identities] FOREIGN KEY ([CreatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SJob].[FeeAmendment]
  ADD CONSTRAINT [FK_FeeAmendment_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SJob].[FeeAmendment]
  ADD CONSTRAINT [FK_FeeAmendment_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO