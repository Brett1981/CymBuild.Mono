PRINT (N'Create table [SMigration].[Onboarding_WorkflowStatusNotificationGroups]')
GO
CREATE TABLE [SMigration].[Onboarding_WorkflowStatusNotificationGroups] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [WorkflowNotificationGroupGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [WorkflowGuid] [uniqueidentifier] NOT NULL,
  [WorkflowStatusGuid] [uniqueidentifier] NOT NULL,
  [GroupGuid] [uniqueidentifier] NOT NULL,
  [CanAction] [bit] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_WSNG] on table [SMigration].[Onboarding_WorkflowStatusNotificationGroups]')
GO
ALTER TABLE [SMigration].[Onboarding_WorkflowStatusNotificationGroups] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_WSNG] PRIMARY KEY CLUSTERED ([RunGuid], [WorkflowNotificationGroupGuid]) WITH (FILLFACTOR = 80)
GO