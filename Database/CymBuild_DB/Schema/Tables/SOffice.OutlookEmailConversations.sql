CREATE TABLE [SOffice].[OutlookEmailConversations] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_OutlookEmailConversations_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_OutlookEmailConversations_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [ConversationID] [nvarchar](250) NOT NULL CONSTRAINT [DF_OutlookEmailConversations_ConversationId] DEFAULT (''),
  CONSTRAINT [PK_OutlookEmailConversations] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_OutlookEmailConversations_ConversationId]
  ON [SOffice].[OutlookEmailConversations] ([ConversationID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SOffice].[OutlookEmailConversations]
  ADD CONSTRAINT [FK_OutlookEmailConversations_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO