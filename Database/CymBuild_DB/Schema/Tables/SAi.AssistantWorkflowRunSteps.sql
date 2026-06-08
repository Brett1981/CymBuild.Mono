PRINT (N'Create table [SAi].[AssistantWorkflowRunSteps]')
GO
CREATE TABLE [SAi].[AssistantWorkflowRunSteps] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [WorkflowRunId] [int] NOT NULL,
  [StepOrder] [int] NOT NULL,
  [Title] [nvarchar](250) NOT NULL,
  [InstructionMarkdown] [nvarchar](max) NOT NULL,
  [StatusCode] [nvarchar](30) NOT NULL,
  [CompletedUtc] [datetime2] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantWorkflowRunSteps] on table [SAi].[AssistantWorkflowRunSteps]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRunSteps] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantWorkflowRunSteps] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantWorkflowRunSteps_Guid] on table [SAi].[AssistantWorkflowRunSteps]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRunSteps] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantWorkflowRunSteps_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantWorkflowRunSteps_RunOrder] on table [SAi].[AssistantWorkflowRunSteps]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRunSteps] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantWorkflowRunSteps_RunOrder] UNIQUE ([WorkflowRunId], [StepOrder]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_AssistantWorkflowRunSteps_DataObjects] on table [SAi].[AssistantWorkflowRunSteps]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRunSteps] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantWorkflowRunSteps_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantWorkflowRunSteps_DataObjects] on table [SAi].[AssistantWorkflowRunSteps]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRunSteps]
  NOCHECK CONSTRAINT [FK_AssistantWorkflowRunSteps_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantWorkflowRunSteps_RowStatus] on table [SAi].[AssistantWorkflowRunSteps]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRunSteps] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantWorkflowRunSteps_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantWorkflowRunSteps_Runs] on table [SAi].[AssistantWorkflowRunSteps]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRunSteps] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantWorkflowRunSteps_Runs] FOREIGN KEY ([WorkflowRunId]) REFERENCES [SAi].[AssistantWorkflowRuns] ([ID])
GO