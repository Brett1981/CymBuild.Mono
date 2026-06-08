PRINT (N'Create table [SMigration].[Onboarding_WorkflowTransitions]')
GO
CREATE TABLE [SMigration].[Onboarding_WorkflowTransitions] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [WorkflowTransitionGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [WorkflowGuid] [uniqueidentifier] NOT NULL,
  [FromStatusGuid] [uniqueidentifier] NOT NULL,
  [ToStatusGuid] [uniqueidentifier] NOT NULL,
  [IsFinal] [bit] NOT NULL,
  [Enabled] [bit] NOT NULL,
  [SortOrder] [int] NOT NULL,
  [Description] [nvarchar](2000) NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_WorkflowTransitions] on table [SMigration].[Onboarding_WorkflowTransitions]')
GO
ALTER TABLE [SMigration].[Onboarding_WorkflowTransitions] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_WorkflowTransitions] PRIMARY KEY CLUSTERED ([RunGuid], [WorkflowTransitionGuid]) WITH (FILLFACTOR = 80)
GO