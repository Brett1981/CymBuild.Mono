PRINT (N'Create table [SJob].[Actions]')
GO
CREATE TABLE [SJob].[Actions] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_Actions_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_Actions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DEFAULT_Actions_JobID] DEFAULT (-1),
  [MilestoneID] [bigint] NOT NULL CONSTRAINT [DF_Actions_MilestoneID] DEFAULT (-1),
  [ActivityID] [bigint] NOT NULL CONSTRAINT [DF_Actions_ActivityID] DEFAULT (-1),
  [SurveyorID] [int] NOT NULL CONSTRAINT [DEFAULT_Actions_SurveyorID] DEFAULT (-1),
  [Notes] [nvarchar](max) NOT NULL CONSTRAINT [DEFAULT_Actions_Notes] DEFAULT (''),
  [CreatedByUserID] [int] NOT NULL CONSTRAINT [DEFAULT_Actions_CreatedByUserID] DEFAULT (-1),
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_Actions_CreatedDateTimeUTC] DEFAULT (getutcdate()),
  [LegacyID] [bigint] NULL,
  [IsComplete] [bit] NOT NULL CONSTRAINT [DF_Actions_IsComplete] DEFAULT (0),
  [AssigneeUserId] [int] NOT NULL CONSTRAINT [DF__Actions__Assigne__75E406C5] DEFAULT (-1),
  [ActionPriorityId] [int] NOT NULL CONSTRAINT [DF__Actions__ActionP__76D82AFE] DEFAULT (-1),
  [ActionTypeId] [int] NOT NULL CONSTRAINT [DF__Actions__ActionT__77CC4F37] DEFAULT (-1),
  [ActionStatusId] [int] NOT NULL CONSTRAINT [DF__Actions__ActionS__192D4302] DEFAULT (-1),
  [PlanCheckItemId] [int] NOT NULL CONSTRAINT [DF_Actions_PlanCheckItemId] DEFAULT (-1),
  [LegacySystemID] [int] NOT NULL DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Actions] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [PK_Actions] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Actions_Activity] on table [SJob].[Actions]')
GO
CREATE INDEX [IX_Actions_Activity]
  ON [SJob].[Actions] ([ActivityID], [RowStatus])
  INCLUDE ([IsComplete])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_JobActions] on table [SJob].[Actions]')
GO
CREATE INDEX [IX_JobActions]
  ON [SJob].[Actions] ([CreatedByUserID] DESC, [JobID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Actions_Guid] on table [SJob].[Actions]')
GO
CREATE UNIQUE INDEX [IX_UQ_Actions_Guid]
  ON [SJob].[Actions] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_Actions_ActionPriorityId] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [FK_Actions_ActionPriorityId] FOREIGN KEY ([ActionPriorityId]) REFERENCES [SJob].[ActionPriorities] ([ID])
GO

PRINT (N'Create foreign key [FK_Actions_ActionStatusId] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [FK_Actions_ActionStatusId] FOREIGN KEY ([ActionStatusId]) REFERENCES [SJob].[ActionStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Actions_ActionTypeId] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [FK_Actions_ActionTypeId] FOREIGN KEY ([ActionTypeId]) REFERENCES [SJob].[ActionTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_Actions_Activity] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [FK_Actions_Activity] FOREIGN KEY ([ActivityID]) REFERENCES [SJob].[Activities] ([ID])
GO

PRINT (N'Create foreign key [FK_Actions_AssigneeUserId] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [FK_Actions_AssigneeUserId] FOREIGN KEY ([AssigneeUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Actions_DataObjects] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [FK_Actions_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_Actions_DataObjects] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions]
  NOCHECK CONSTRAINT [FK_Actions_DataObjects]
GO

PRINT (N'Create foreign key [FK_Actions_Identities] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [FK_Actions_Identities] FOREIGN KEY ([SurveyorID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Actions_Identities1] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [FK_Actions_Identities1] FOREIGN KEY ([CreatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Actions_Jobs] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [FK_Actions_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_Actions_Milestones] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [FK_Actions_Milestones] FOREIGN KEY ([MilestoneID]) REFERENCES [SJob].[Milestones] ([ID])
GO

PRINT (N'Create foreign key [FK_Actions_RowStatus] on table [SJob].[Actions]')
GO
ALTER TABLE [SJob].[Actions] WITH NOCHECK
  ADD CONSTRAINT [FK_Actions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO