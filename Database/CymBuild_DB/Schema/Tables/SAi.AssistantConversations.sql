PRINT (N'Create table [SAi].[AssistantConversations]')
GO
CREATE TABLE [SAi].[AssistantConversations] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [UserId] [int] NOT NULL,
  [Title] [nvarchar](250) NOT NULL,
  [ModeCode] [nvarchar](20) NOT NULL,
  [LanguageCode] [nvarchar](20) NULL,
  [LastActivityUtc] [datetime2] NOT NULL,
  [IsPinned] [bit] NOT NULL CONSTRAINT [DF_AssistantConversations_IsPinned] DEFAULT (0),
  [IsArchived] [bit] NOT NULL CONSTRAINT [DF_AssistantConversations_IsArchived] DEFAULT (0),
  [StartedFromWorkflowTemplateId] [int] NULL,
  [LastMessageId] [int] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantConversations] on table [SAi].[AssistantConversations]')
GO
ALTER TABLE [SAi].[AssistantConversations] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantConversations] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantConversations_Guid] on table [SAi].[AssistantConversations]')
GO
ALTER TABLE [SAi].[AssistantConversations] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantConversations_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantConversations_User_LastActivity] on table [SAi].[AssistantConversations]')
GO
CREATE INDEX [IX_AssistantConversations_User_LastActivity]
  ON [SAi].[AssistantConversations] ([UserId], [LastActivityUtc] DESC)
  INCLUDE ([Title], [ModeCode], [IsArchived], [IsPinned])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantConversations_DataObjects] on table [SAi].[AssistantConversations]')
GO
ALTER TABLE [SAi].[AssistantConversations] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantConversations_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantConversations_DataObjects] on table [SAi].[AssistantConversations]')
GO
ALTER TABLE [SAi].[AssistantConversations]
  NOCHECK CONSTRAINT [FK_AssistantConversations_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantConversations_Identities_User] on table [SAi].[AssistantConversations]')
GO
ALTER TABLE [SAi].[AssistantConversations] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantConversations_Identities_User] FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantConversations_LastMessage] on table [SAi].[AssistantConversations]')
GO
ALTER TABLE [SAi].[AssistantConversations] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantConversations_LastMessage] FOREIGN KEY ([LastMessageId]) REFERENCES [SAi].[AssistantMessages] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantConversations_RowStatus] on table [SAi].[AssistantConversations]')
GO
ALTER TABLE [SAi].[AssistantConversations] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantConversations_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantConversations_WorkflowTemplate] on table [SAi].[AssistantConversations]')
GO
ALTER TABLE [SAi].[AssistantConversations] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantConversations_WorkflowTemplate] FOREIGN KEY ([StartedFromWorkflowTemplateId]) REFERENCES [SAi].[AssistantWorkflowTemplates] ([ID])
GO