CREATE TABLE [SJob].[JobTypeActivityTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobTypeActivityTypes_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobTypeActivityTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobTypeID] [int] NOT NULL CONSTRAINT [DF_JobTypeActivityTypes_JobTypeID] DEFAULT (-1),
  [ActivityTypeID] [int] NOT NULL CONSTRAINT [DF_JobTypeActivityTypes_ActivityTypeID] DEFAULT (-1),
  CONSTRAINT [PK_JobTypeActivityTypes] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_JobTypeActivityTypes]
  ON [SJob].[JobTypeActivityTypes] ([JobTypeID], [ActivityTypeID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_JobTypeActivityTypes_Guid]
  ON [SJob].[JobTypeActivityTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[JobTypeActivityTypes]
  ADD CONSTRAINT [FK_JobTypeActivityTypes_ActivityTypes] FOREIGN KEY ([ActivityTypeID]) REFERENCES [SJob].[ActivityTypes] ([ID])
GO

ALTER TABLE [SJob].[JobTypeActivityTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeActivityTypes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[JobTypeActivityTypes]
  NOCHECK CONSTRAINT [FK_JobTypeActivityTypes_DataObjects]
GO

ALTER TABLE [SJob].[JobTypeActivityTypes]
  ADD CONSTRAINT [FK_JobTypeActivityTypes_JobTypes] FOREIGN KEY ([JobTypeID]) REFERENCES [SJob].[JobTypes] ([ID])
GO

ALTER TABLE [SJob].[JobTypeActivityTypes]
  ADD CONSTRAINT [FK_JobTypeActivityTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO