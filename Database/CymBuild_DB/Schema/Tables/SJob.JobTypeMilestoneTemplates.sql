CREATE TABLE [SJob].[JobTypeMilestoneTemplates] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobTypeID] [int] NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_JobTypeID] DEFAULT (-1),
  [MilestoneTypeID] [int] NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_MilestoneTypeID] DEFAULT (-1),
  [Description] [nvarchar](500) NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_Description] DEFAULT (''),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_SortOrder] DEFAULT (0),
  CONSTRAINT [PK_JobTypeMilestoneTemplates] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_JobTypeMilestoneTemplates_JobType_MilestoneType]
  ON [SJob].[JobTypeMilestoneTemplates] ([JobTypeID], [MilestoneTypeID], [SortOrder])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_JobTypeMilestoneTemplates_Guid]
  ON [SJob].[JobTypeMilestoneTemplates] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[JobTypeMilestoneTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeMilestoneTemplates_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[JobTypeMilestoneTemplates]
  NOCHECK CONSTRAINT [FK_JobTypeMilestoneTemplates_DataObjects]
GO

ALTER TABLE [SJob].[JobTypeMilestoneTemplates]
  ADD CONSTRAINT [FK_JobTypeMilestoneTemplates_JobTypes] FOREIGN KEY ([JobTypeID]) REFERENCES [SJob].[JobTypes] ([ID])
GO

ALTER TABLE [SJob].[JobTypeMilestoneTemplates]
  ADD CONSTRAINT [FK_JobTypeMilestoneTemplates_MilestoneTypes] FOREIGN KEY ([MilestoneTypeID]) REFERENCES [SJob].[MilestoneTypes] ([ID])
GO

ALTER TABLE [SJob].[JobTypeMilestoneTemplates]
  ADD CONSTRAINT [FK_JobTypeMilestoneTemplates_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO