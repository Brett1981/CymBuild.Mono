PRINT (N'Create table [SAi].[AssistantFeedback]')
GO
CREATE TABLE [SAi].[AssistantFeedback] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [UserId] [int] NOT NULL,
  [ConversationId] [int] NOT NULL,
  [MessageId] [int] NOT NULL,
  [FeedbackCode] [nvarchar](20) NOT NULL,
  [Comment] [nvarchar](max) NULL,
  [CreatedUtc] [datetime2] NOT NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantFeedback] on table [SAi].[AssistantFeedback]')
GO
ALTER TABLE [SAi].[AssistantFeedback] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantFeedback] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantFeedback_Guid] on table [SAi].[AssistantFeedback]')
GO
ALTER TABLE [SAi].[AssistantFeedback] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantFeedback_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantFeedback_Message] on table [SAi].[AssistantFeedback]')
GO
CREATE INDEX [IX_AssistantFeedback_Message]
  ON [SAi].[AssistantFeedback] ([MessageId], [CreatedUtc] DESC)
  INCLUDE ([FeedbackCode], [UserId], [ConversationId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantFeedback_Conversations] on table [SAi].[AssistantFeedback]')
GO
ALTER TABLE [SAi].[AssistantFeedback] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantFeedback_Conversations] FOREIGN KEY ([ConversationId]) REFERENCES [SAi].[AssistantConversations] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantFeedback_DataObjects] on table [SAi].[AssistantFeedback]')
GO
ALTER TABLE [SAi].[AssistantFeedback] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantFeedback_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantFeedback_DataObjects] on table [SAi].[AssistantFeedback]')
GO
ALTER TABLE [SAi].[AssistantFeedback]
  NOCHECK CONSTRAINT [FK_AssistantFeedback_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantFeedback_Identities_User] on table [SAi].[AssistantFeedback]')
GO
ALTER TABLE [SAi].[AssistantFeedback] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantFeedback_Identities_User] FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantFeedback_Messages] on table [SAi].[AssistantFeedback]')
GO
ALTER TABLE [SAi].[AssistantFeedback] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantFeedback_Messages] FOREIGN KEY ([MessageId]) REFERENCES [SAi].[AssistantMessages] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantFeedback_RowStatus] on table [SAi].[AssistantFeedback]')
GO
ALTER TABLE [SAi].[AssistantFeedback] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantFeedback_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO