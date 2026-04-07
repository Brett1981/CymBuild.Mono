PRINT (N'Create table [SJob].[Activities]')
GO
CREATE TABLE [SJob].[Activities] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_Activity_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_Activity_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_JobID] DEFAULT (-1),
  [MilestoneID] [bigint] NOT NULL CONSTRAINT [DF_Activity_MilestoneID] DEFAULT (-1),
  [SurveyorID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_SurveyorID] DEFAULT (-1),
  [Date] [datetime2] NOT NULL CONSTRAINT [DEFAULT_Activity_Date] DEFAULT (getdate()),
  [EndDate] [datetime2] NOT NULL CONSTRAINT [DEFAULT_Activity_EndDate] DEFAULT (getdate()),
  [ActivityTypeID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_ActivityTypeID] DEFAULT (-1),
  [ActivityStatusID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_ActivityStatusID] DEFAULT (-1),
  [Title] [nvarchar](250) NOT NULL CONSTRAINT [DEFAULT_Activity_Title] DEFAULT (''),
  [Notes] [nvarchar](max) NOT NULL CONSTRAINT [DEFAULT_Activity_Notes] DEFAULT (''),
  [CreatedByUserID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_CreatedByUserID] DEFAULT (-1),
  [LastUpdatedByUserID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_LastUpdatedByUserID] DEFAULT (-1),
  [VersionID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_VersionID] DEFAULT (-1),
  [InvoicingQuantity] [decimal](19, 2) NOT NULL CONSTRAINT [DEFAULT_Activity_InvoicingQuantity] DEFAULT (0),
  [LegacyID] [bigint] NULL,
  [ExchangeId] [nvarchar](500) NOT NULL CONSTRAINT [DF_Activities_ExchangeId] DEFAULT (''),
  [IsAdditionalWork] [bit] NOT NULL CONSTRAINT [DF_Activities_IsAdditionalWork] DEFAULT (0),
  [RibaStageId] [int] NOT NULL CONSTRAINT [DF_Activities_RibaStageId] DEFAULT (-1),
  [InvoicingValue] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Activities_InvoicingValue] DEFAULT (0),
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [NewExpiryDate] [datetime] NULL CONSTRAINT [DF_Activities_NewExpiryDate] DEFAULT (NULL),
  [CompletedDateTimeUTC] [datetime2] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Activity] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [PK_Activity] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Activities_JobId] on table [SJob].[Activities]')
GO
CREATE INDEX [IX_Activities_JobId]
  ON [SJob].[Activities] ([JobID], [RowStatus], [Date] DESC)
  INCLUDE ([ActivityStatusID], [ActivityTypeID], [EndDate])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Activities_Stage] on table [SJob].[Activities]')
GO
CREATE INDEX [IX_Activities_Stage]
  ON [SJob].[Activities] ([RibaStageId], [RowStatus])
  INCLUDE ([JobID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Activities_Surveyor] on table [SJob].[Activities]')
GO
CREATE INDEX [IX_Activities_Surveyor]
  ON [SJob].[Activities] ([SurveyorID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_JobActivity] on table [SJob].[Activities]')
GO
CREATE INDEX [IX_JobActivity]
  ON [SJob].[Activities] ([Date] DESC, [JobID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Activities_Guid] on table [SJob].[Activities]')
GO
CREATE UNIQUE INDEX [IX_UQ_Activities_Guid]
  ON [SJob].[Activities] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_Activities_ActivityStatus] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_ActivityStatus] FOREIGN KEY ([ActivityStatusID]) REFERENCES [SJob].[ActivityStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_ActivityTypes] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_ActivityTypes] FOREIGN KEY ([ActivityTypeID]) REFERENCES [SJob].[ActivityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_DataObjects] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_Activities_DataObjects] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities]
  NOCHECK CONSTRAINT [FK_Activities_DataObjects]
GO

PRINT (N'Create foreign key [FK_Activities_Identities] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_Identities] FOREIGN KEY ([SurveyorID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_Identities1] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_Identities1] FOREIGN KEY ([CreatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_Identities2] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_Identities2] FOREIGN KEY ([LastUpdatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_Jobs] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_Activities_Milestones] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_Milestones] FOREIGN KEY ([MilestoneID]) REFERENCES [SJob].[Milestones] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_RibaStages] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_RibaStages] FOREIGN KEY ([RibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_RowStatus] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO