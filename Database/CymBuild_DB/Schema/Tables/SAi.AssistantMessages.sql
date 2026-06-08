PRINT (N'Create table [SAi].[AssistantMessages]')
GO
CREATE TABLE [SAi].[AssistantMessages] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [ConversationId] [int] NOT NULL,
  [UserId] [int] NOT NULL,
  [MessageRoleCode] [nvarchar](20) NOT NULL,
  [AnswerTypeCode] [nvarchar](30) NULL,
  [ContentMarkdown] [nvarchar](max) NOT NULL,
  [ContentPlainText] [nvarchar](max) NULL,
  [SourcePayloadJson] [nvarchar](max) NULL,
  [FollowUpPayloadJson] [nvarchar](max) NULL,
  [ConfidenceScore] [decimal](5, 4) NULL,
  [CreatedUtc] [datetime2] NOT NULL,
  [PromptTokens] [int] NULL,
  [CompletionTokens] [int] NULL,
  [ModelCode] [nvarchar](100) NULL,
  [ParentMessageId] [int] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantMessages] on table [SAi].[AssistantMessages]')
GO
ALTER TABLE [SAi].[AssistantMessages] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantMessages] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantMessages_Guid] on table [SAi].[AssistantMessages]')
GO
ALTER TABLE [SAi].[AssistantMessages] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantMessages_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantMessages_Conversation_CreatedUtc] on table [SAi].[AssistantMessages]')
GO
CREATE INDEX [IX_AssistantMessages_Conversation_CreatedUtc]
  ON [SAi].[AssistantMessages] ([ConversationId], [CreatedUtc])
  INCLUDE ([MessageRoleCode], [AnswerTypeCode], [ConfidenceScore])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantMessages_Conversations] on table [SAi].[AssistantMessages]')
GO
ALTER TABLE [SAi].[AssistantMessages] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantMessages_Conversations] FOREIGN KEY ([ConversationId]) REFERENCES [SAi].[AssistantConversations] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantMessages_DataObjects] on table [SAi].[AssistantMessages]')
GO
ALTER TABLE [SAi].[AssistantMessages] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantMessages_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantMessages_DataObjects] on table [SAi].[AssistantMessages]')
GO
ALTER TABLE [SAi].[AssistantMessages]
  NOCHECK CONSTRAINT [FK_AssistantMessages_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantMessages_Identities_User] on table [SAi].[AssistantMessages]')
GO
ALTER TABLE [SAi].[AssistantMessages] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantMessages_Identities_User] FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantMessages_ParentMessage] on table [SAi].[AssistantMessages]')
GO
ALTER TABLE [SAi].[AssistantMessages] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantMessages_ParentMessage] FOREIGN KEY ([ParentMessageId]) REFERENCES [SAi].[AssistantMessages] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantMessages_RowStatus] on table [SAi].[AssistantMessages]')
GO
ALTER TABLE [SAi].[AssistantMessages] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantMessages_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO