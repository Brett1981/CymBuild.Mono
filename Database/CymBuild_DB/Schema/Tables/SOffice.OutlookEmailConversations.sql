PRINT (N'Create table [SOffice].[OutlookEmailConversations]')
GO
PRINT (N'Create table [SOffice].[OutlookEmailConversations]')
GO
CREATE TABLE [SOffice].[OutlookEmailConversations] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_OutlookEmailConversations_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_OutlookEmailConversations_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [ConversationID] [nvarchar](250) NOT NULL CONSTRAINT [DF_OutlookEmailConversations_ConversationId] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_OutlookEmailConversations] on table [SOffice].[OutlookEmailConversations]')
GO
ALTER TABLE [SOffice].[OutlookEmailConversations] WITH NOCHECK
  ADD CONSTRAINT [PK_OutlookEmailConversations] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_OutlookEmailConversations_ConversationId] on table [SOffice].[OutlookEmailConversations]')
GO
CREATE UNIQUE INDEX [IX_UQ_OutlookEmailConversations_ConversationId]
  ON [SOffice].[OutlookEmailConversations] ([ConversationID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_OutlookEmailConversations_RowStatus] on table [SOffice].[OutlookEmailConversations]')
GO
ALTER TABLE [SOffice].[OutlookEmailConversations] WITH NOCHECK
  ADD CONSTRAINT [FK_OutlookEmailConversations_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO