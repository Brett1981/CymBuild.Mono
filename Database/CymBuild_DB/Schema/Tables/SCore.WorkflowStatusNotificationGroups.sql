CREATE TABLE [SCore].[WorkflowStatusNotificationGroups] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_Guid] DEFAULT (newid()),
  [WorkflowID] [int] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_WorkflowID] DEFAULT (-1),
  [WorkflowStatusGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_WorkflowStatusGuid] DEFAULT (newid()),
  [GroupID] [int] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_GroupID] DEFAULT (-1),
  [CanAction] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_CanAction] DEFAULT (0),
  CONSTRAINT [PK_WorkflowStatusNotificationGroups] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_WorkflowStatusNotificationGroups_Lookup]
  ON [SCore].[WorkflowStatusNotificationGroups] ([RowStatus], [WorkflowID], [WorkflowStatusGuid])
  INCLUDE ([GroupID], [CanAction])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_WorkflowStatusNotificationGroups_Workflow_Status]
  ON [SCore].[WorkflowStatusNotificationGroups] ([WorkflowID], [WorkflowStatusGuid])
  INCLUDE ([GroupID], [CanAction])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [UX_WorkflowStatusNotificationGroups_Workflow_Status_Group]
  ON [SCore].[WorkflowStatusNotificationGroups] ([WorkflowID], [WorkflowStatusGuid], [GroupID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[WorkflowStatusNotificationGroups]
  ADD CONSTRAINT [FK_WFStatusNotificationGroups_Groups] FOREIGN KEY ([GroupID]) REFERENCES [SCore].[Groups] ([ID])
GO

ALTER TABLE [SCore].[WorkflowStatusNotificationGroups]
  ADD CONSTRAINT [FK_WFStatusNotificationGroups_Workflow] FOREIGN KEY ([WorkflowID]) REFERENCES [SCore].[Workflow] ([ID])
GO