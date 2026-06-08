PRINT (N'Create table [SAi].[AssistantBookmarks]')
GO
CREATE TABLE [SAi].[AssistantBookmarks] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [UserId] [int] NOT NULL,
  [ConversationId] [int] NOT NULL,
  [MessageId] [int] NOT NULL,
  [Title] [nvarchar](250) NOT NULL,
  [Notes] [nvarchar](max) NULL,
  [TagsJson] [nvarchar](max) NULL,
  [CreatedUtc] [datetime2] NOT NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantBookmarks] on table [SAi].[AssistantBookmarks]')
GO
ALTER TABLE [SAi].[AssistantBookmarks] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantBookmarks] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantBookmarks_Guid] on table [SAi].[AssistantBookmarks]')
GO
ALTER TABLE [SAi].[AssistantBookmarks] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantBookmarks_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantBookmarks_User_CreatedUtc] on table [SAi].[AssistantBookmarks]')
GO
CREATE INDEX [IX_AssistantBookmarks_User_CreatedUtc]
  ON [SAi].[AssistantBookmarks] ([UserId], [CreatedUtc] DESC)
  INCLUDE ([ConversationId], [MessageId], [Title])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantBookmarks_Conversations] on table [SAi].[AssistantBookmarks]')
GO
ALTER TABLE [SAi].[AssistantBookmarks] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantBookmarks_Conversations] FOREIGN KEY ([ConversationId]) REFERENCES [SAi].[AssistantConversations] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantBookmarks_DataObjects] on table [SAi].[AssistantBookmarks]')
GO
ALTER TABLE [SAi].[AssistantBookmarks] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantBookmarks_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantBookmarks_DataObjects] on table [SAi].[AssistantBookmarks]')
GO
ALTER TABLE [SAi].[AssistantBookmarks]
  NOCHECK CONSTRAINT [FK_AssistantBookmarks_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantBookmarks_Identities_User] on table [SAi].[AssistantBookmarks]')
GO
ALTER TABLE [SAi].[AssistantBookmarks] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantBookmarks_Identities_User] FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantBookmarks_Messages] on table [SAi].[AssistantBookmarks]')
GO
ALTER TABLE [SAi].[AssistantBookmarks] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantBookmarks_Messages] FOREIGN KEY ([MessageId]) REFERENCES [SAi].[AssistantMessages] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantBookmarks_RowStatus] on table [SAi].[AssistantBookmarks]')
GO
ALTER TABLE [SAi].[AssistantBookmarks] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantBookmarks_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO