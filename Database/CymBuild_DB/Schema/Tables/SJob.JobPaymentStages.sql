PRINT (N'Create table [SJob].[JobPaymentStages]')
GO
CREATE TABLE [SJob].[JobPaymentStages] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobPaymentStages_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobPaymentStages_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobId] [int] NOT NULL CONSTRAINT [DF_JobPaymentStages_JobId] DEFAULT (-1),
  [StagedDate] [date] NULL,
  [AfterStageId] [int] NOT NULL CONSTRAINT [DF_JobPaymentStages_AfterStageId] DEFAULT (-1),
  [Value] [decimal](18, 2) NOT NULL CONSTRAINT [DF_JobPaymentStages_Value] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_JobPaymentStages] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages] WITH NOCHECK
  ADD CONSTRAINT [PK_JobPaymentStages] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_JobPaymentStage_Job] on table [SJob].[JobPaymentStages]')
GO
CREATE INDEX [IX_JobPaymentStage_Job]
  ON [SJob].[JobPaymentStages] ([JobId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_JobPaymentStages_Guid] on table [SJob].[JobPaymentStages]')
GO
CREATE UNIQUE INDEX [IX_UQ_JobPaymentStages_Guid]
  ON [SJob].[JobPaymentStages] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_JobPaymentStages_DataObjects] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPaymentStages_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_JobPaymentStages_DataObjects] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages]
  NOCHECK CONSTRAINT [FK_JobPaymentStages_DataObjects]
GO

PRINT (N'Create foreign key [FK_JobPaymentStages_Jobs] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPaymentStages_Jobs] FOREIGN KEY ([JobId]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_JobPaymentStages_RibaStages] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPaymentStages_RibaStages] FOREIGN KEY ([AfterStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_JobPaymentStages_RowStatus] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPaymentStages_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO