PRINT (N'Create table [SAi].[AssistantWorkflowRuns]')
GO
CREATE TABLE [SAi].[AssistantWorkflowRuns] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [UserId] [int] NOT NULL,
  [WorkflowTemplateId] [int] NOT NULL,
  [ConversationId] [int] NULL,
  [StatusCode] [nvarchar](30) NOT NULL,
  [InputJson] [nvarchar](max) NULL,
  [OutputJson] [nvarchar](max) NULL,
  [StartedUtc] [datetime2] NOT NULL,
  [CompletedUtc] [datetime2] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantWorkflowRuns] on table [SAi].[AssistantWorkflowRuns]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRuns] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantWorkflowRuns] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantWorkflowRuns_Guid] on table [SAi].[AssistantWorkflowRuns]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRuns] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantWorkflowRuns_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantWorkflowRuns_User_StartedUtc] on table [SAi].[AssistantWorkflowRuns]')
GO
CREATE INDEX [IX_AssistantWorkflowRuns_User_StartedUtc]
  ON [SAi].[AssistantWorkflowRuns] ([UserId], [StartedUtc] DESC)
  INCLUDE ([WorkflowTemplateId], [StatusCode], [ConversationId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantWorkflowRuns_Conversations] on table [SAi].[AssistantWorkflowRuns]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRuns] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantWorkflowRuns_Conversations] FOREIGN KEY ([ConversationId]) REFERENCES [SAi].[AssistantConversations] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantWorkflowRuns_DataObjects] on table [SAi].[AssistantWorkflowRuns]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRuns] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantWorkflowRuns_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantWorkflowRuns_DataObjects] on table [SAi].[AssistantWorkflowRuns]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRuns]
  NOCHECK CONSTRAINT [FK_AssistantWorkflowRuns_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantWorkflowRuns_Identities_User] on table [SAi].[AssistantWorkflowRuns]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRuns] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantWorkflowRuns_Identities_User] FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantWorkflowRuns_RowStatus] on table [SAi].[AssistantWorkflowRuns]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRuns] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantWorkflowRuns_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantWorkflowRuns_Templates] on table [SAi].[AssistantWorkflowRuns]')
GO
ALTER TABLE [SAi].[AssistantWorkflowRuns] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantWorkflowRuns_Templates] FOREIGN KEY ([WorkflowTemplateId]) REFERENCES [SAi].[AssistantWorkflowTemplates] ([ID])
GO