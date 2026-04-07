CREATE TABLE [SJob].[ProductJobActivities] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ProductJobActivities_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ProductJobActivities_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ProductId] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_ProductId] DEFAULT (-1),
  [JobTypeActivityTypeId] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_JobTypeActivityTypeId] DEFAULT (-1),
  [ActivityTitle] [nvarchar](250) NOT NULL CONSTRAINT [DF_ProductJobActivities_ActivityTitle] DEFAULT (''),
  [OffsetDays] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_OffsetDays] DEFAULT (0),
  [OffsetWeeks] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_OffsetWeeks] DEFAULT (0),
  [OffsetMonths] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_OffsetMonths] DEFAULT (0),
  [JobTypeMilestoneTemplateId] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_JobTypeMilestoneTemplateId] DEFAULT (-1),
  [PercentageOfProductValue] [decimal](5, 2) NOT NULL CONSTRAINT [DF_ProductJobActivities_PercentageOfProductValue] DEFAULT (0),
  CONSTRAINT [PK_ProductJobActivities] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE INDEX [IX_ProductJobActivities_Product]
  ON [SJob].[ProductJobActivities] ([ProductId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ProductJobActivities_Guid]
  ON [SJob].[ProductJobActivities] ([Guid])
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[ProductJobActivities] WITH NOCHECK
  ADD CONSTRAINT [FK_ProductJobActivities_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[ProductJobActivities]
  NOCHECK CONSTRAINT [FK_ProductJobActivities_DataObjects]
GO

ALTER TABLE [SJob].[ProductJobActivities]
  ADD CONSTRAINT [FK_ProductJobActivities_JobTypeActivityTypes] FOREIGN KEY ([JobTypeActivityTypeId]) REFERENCES [SJob].[JobTypeActivityTypes] ([ID])
GO

ALTER TABLE [SJob].[ProductJobActivities]
  ADD CONSTRAINT [FK_ProductJobActivities_JobTypeMilestoneTemplates] FOREIGN KEY ([JobTypeMilestoneTemplateId]) REFERENCES [SJob].[JobTypeMilestoneTemplates] ([ID])
GO

ALTER TABLE [SJob].[ProductJobActivities]
  ADD CONSTRAINT [FK_ProductJobActivities_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO