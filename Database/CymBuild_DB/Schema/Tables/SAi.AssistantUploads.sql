PRINT (N'Create table [SAi].[AssistantUploads]')
GO
CREATE TABLE [SAi].[AssistantUploads] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [UserId] [int] NOT NULL,
  [ConversationId] [int] NULL,
  [KnowledgeItemId] [int] NULL,
  [StorageUrl] [nvarchar](1000) NOT NULL,
  [FileName] [nvarchar](500) NOT NULL,
  [ContentType] [nvarchar](200) NOT NULL,
  [FileSizeBytes] [bigint] NOT NULL,
  [UploadPurposeCode] [nvarchar](30) NOT NULL,
  [ProcessingStatusCode] [nvarchar](30) NOT NULL,
  [VisionSummary] [nvarchar](max) NULL,
  [CreatedUtc] [datetime2] NOT NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantUploads] on table [SAi].[AssistantUploads]')
GO
ALTER TABLE [SAi].[AssistantUploads] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantUploads] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantUploads_Guid] on table [SAi].[AssistantUploads]')
GO
ALTER TABLE [SAi].[AssistantUploads] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantUploads_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantUploads_User_CreatedUtc] on table [SAi].[AssistantUploads]')
GO
CREATE INDEX [IX_AssistantUploads_User_CreatedUtc]
  ON [SAi].[AssistantUploads] ([UserId], [CreatedUtc] DESC)
  INCLUDE ([ConversationId], [KnowledgeItemId], [UploadPurposeCode], [ProcessingStatusCode], [FileName])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantUploads_Conversations] on table [SAi].[AssistantUploads]')
GO
ALTER TABLE [SAi].[AssistantUploads] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantUploads_Conversations] FOREIGN KEY ([ConversationId]) REFERENCES [SAi].[AssistantConversations] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantUploads_DataObjects] on table [SAi].[AssistantUploads]')
GO
ALTER TABLE [SAi].[AssistantUploads] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantUploads_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantUploads_DataObjects] on table [SAi].[AssistantUploads]')
GO
ALTER TABLE [SAi].[AssistantUploads]
  NOCHECK CONSTRAINT [FK_AssistantUploads_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantUploads_Identities_User] on table [SAi].[AssistantUploads]')
GO
ALTER TABLE [SAi].[AssistantUploads] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantUploads_Identities_User] FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantUploads_KnowledgeItems] on table [SAi].[AssistantUploads]')
GO
ALTER TABLE [SAi].[AssistantUploads] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantUploads_KnowledgeItems] FOREIGN KEY ([KnowledgeItemId]) REFERENCES [SAi].[AssistantKnowledgeItems] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantUploads_RowStatus] on table [SAi].[AssistantUploads]')
GO
ALTER TABLE [SAi].[AssistantUploads] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantUploads_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO