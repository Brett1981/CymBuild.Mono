PRINT (N'Create table [SAi].[AssistantAnalyticsEvents]')
GO
CREATE TABLE [SAi].[AssistantAnalyticsEvents] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [UserId] [int] NULL,
  [ConversationId] [int] NULL,
  [EventTypeCode] [nvarchar](50) NOT NULL,
  [EventUtc] [datetime2] NOT NULL,
  [TopicText] [nvarchar](1000) NULL,
  [PayloadJson] [nvarchar](max) NULL,
  [SuccessFlag] [bit] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantAnalyticsEvents] on table [SAi].[AssistantAnalyticsEvents]')
GO
ALTER TABLE [SAi].[AssistantAnalyticsEvents] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantAnalyticsEvents] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantAnalyticsEvents_Guid] on table [SAi].[AssistantAnalyticsEvents]')
GO
ALTER TABLE [SAi].[AssistantAnalyticsEvents] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantAnalyticsEvents_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantAnalyticsEvents_EventUtc_Type] on table [SAi].[AssistantAnalyticsEvents]')
GO
CREATE INDEX [IX_AssistantAnalyticsEvents_EventUtc_Type]
  ON [SAi].[AssistantAnalyticsEvents] ([EventUtc] DESC, [EventTypeCode])
  INCLUDE ([UserId], [ConversationId], [SuccessFlag], [TopicText])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantAnalyticsEvents_Conversations] on table [SAi].[AssistantAnalyticsEvents]')
GO
ALTER TABLE [SAi].[AssistantAnalyticsEvents] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantAnalyticsEvents_Conversations] FOREIGN KEY ([ConversationId]) REFERENCES [SAi].[AssistantConversations] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantAnalyticsEvents_DataObjects] on table [SAi].[AssistantAnalyticsEvents]')
GO
ALTER TABLE [SAi].[AssistantAnalyticsEvents] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantAnalyticsEvents_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantAnalyticsEvents_DataObjects] on table [SAi].[AssistantAnalyticsEvents]')
GO
ALTER TABLE [SAi].[AssistantAnalyticsEvents]
  NOCHECK CONSTRAINT [FK_AssistantAnalyticsEvents_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantAnalyticsEvents_Identities_User] on table [SAi].[AssistantAnalyticsEvents]')
GO
ALTER TABLE [SAi].[AssistantAnalyticsEvents] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantAnalyticsEvents_Identities_User] FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantAnalyticsEvents_RowStatus] on table [SAi].[AssistantAnalyticsEvents]')
GO
ALTER TABLE [SAi].[AssistantAnalyticsEvents] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantAnalyticsEvents_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO