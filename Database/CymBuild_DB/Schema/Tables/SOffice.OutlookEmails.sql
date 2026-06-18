SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SOffice].[OutlookEmails]')
GO
CREATE TABLE [SOffice].[OutlookEmails] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_OutlookEmails_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_OutlookEmails_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [TargetObjectID] [bigint] NOT NULL CONSTRAINT [DF_OutlookEmails_RecordID] DEFAULT (-1),
  [OutlookEmailMailboxID] [int] NOT NULL CONSTRAINT [DF_OutlookEmails_Mailbox] DEFAULT (-1),
  [MessageID] [nvarchar](250) NOT NULL CONSTRAINT [DF_OutlookEmails_MessageID] DEFAULT (''),
  [OutlookEmailConversationId] [bigint] NOT NULL CONSTRAINT [DF_OutlookEmails_ConversationId] DEFAULT (-1),
  [OutlookEmailFromAddressID] [int] NOT NULL CONSTRAINT [DF_OutlookEmails_From] DEFAULT (-1),
  [ToAddresses] [nvarchar](4000) NOT NULL CONSTRAINT [DF_OutlookEmails_ToAddresses] DEFAULT (''),
  [Subject] [nvarchar](2000) NOT NULL CONSTRAINT [DF_OutlookEmails_Subject] DEFAULT (''),
  [SentDateTime] [datetime2] NULL,
  [DeliveryReceiptRequested] [bit] NOT NULL CONSTRAINT [DF_OutlookEmails_DeliveryReceiptRequested] DEFAULT (0),
  [DeliveryReceiptReceived] [bit] NOT NULL CONSTRAINT [DF_OutlookEmails_DeliveryReceiptReceived] DEFAULT (0),
  [ReadReceiptRequested] [bit] NOT NULL CONSTRAINT [DF_OutlookEmails_ReadReceiptRequested] DEFAULT (0),
  [ReadReceiptReceived] [bit] NOT NULL CONSTRAINT [DF_OutlookEmails_ReadReceiptReceived] DEFAULT (0),
  [DoNotFile] [bit] NOT NULL CONSTRAINT [DF_OutlookEmails_DoNotFile] DEFAULT (0),
  [IsReadyToFile] [bit] NOT NULL CONSTRAINT [DF_OutlookEmails_IsReadyToFile] DEFAULT (0),
  [FiledDateTime] [datetime2] NULL,
  [IsFiled] AS (case when [FiledDateTime] IS NOT NULL then (1) else (0) end) PERSISTED NOT NULL,
  [FilingLocationUrl] [nvarchar](500) NOT NULL DEFAULT (''),
  [SearchSubject] AS (CONVERT([nvarchar](2000),replace([Subject],N'RE: ',N''))) PERSISTED,
  [Description] [nvarchar](4000) NULL CONSTRAINT [DF_OutlookEmails_Description] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_OutlookEmails] on table [SOffice].[OutlookEmails]')
GO
ALTER TABLE [SOffice].[OutlookEmails] WITH NOCHECK
  ADD CONSTRAINT [PK_OutlookEmails] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_OutlookEmails_IsFiled_Subject] on table [SOffice].[OutlookEmails]')
GO
CREATE INDEX [IX_OutlookEmails_IsFiled_Subject]
  ON [SOffice].[OutlookEmails] ([IsFiled], [SearchSubject])
  INCLUDE ([ToAddresses], [OutlookEmailFromAddressID], [TargetObjectID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SOffice_OutlookEmails_144059650] on table [SOffice].[OutlookEmails]')
GO
CREATE INDEX [IX_SOffice_OutlookEmails_144059650]
  ON [SOffice].[OutlookEmails] ([RowStatus], [SentDateTime])
  INCLUDE ([TargetObjectID], [MessageID], [OutlookEmailConversationId], [FiledDateTime], [FilingLocationUrl])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_OutlookEmails_OutlookEmailConversations] on table [SOffice].[OutlookEmails]')
GO
ALTER TABLE [SOffice].[OutlookEmails] WITH NOCHECK
  ADD CONSTRAINT [FK_OutlookEmails_OutlookEmailConversations] FOREIGN KEY ([OutlookEmailConversationId]) REFERENCES [SOffice].[OutlookEmailConversations] ([ID])
GO

PRINT (N'Create foreign key [FK_OutlookEmails_OutlookEmailFromAddresses] on table [SOffice].[OutlookEmails]')
GO
ALTER TABLE [SOffice].[OutlookEmails] WITH NOCHECK
  ADD CONSTRAINT [FK_OutlookEmails_OutlookEmailFromAddresses] FOREIGN KEY ([OutlookEmailFromAddressID]) REFERENCES [SOffice].[OutlookEmailFromAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_OutlookEmails_OutlookEmails] on table [SOffice].[OutlookEmails]')
GO
ALTER TABLE [SOffice].[OutlookEmails] WITH NOCHECK
  ADD CONSTRAINT [FK_OutlookEmails_OutlookEmails] FOREIGN KEY ([OutlookEmailMailboxID]) REFERENCES [SOffice].[OutlookEmailMailboxes] ([ID])
GO

PRINT (N'Create foreign key [FK_OutlookEmails_RowStatus] on table [SOffice].[OutlookEmails]')
GO
ALTER TABLE [SOffice].[OutlookEmails] WITH NOCHECK
  ADD CONSTRAINT [FK_OutlookEmails_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_OutlookEmails_TargetObjects] on table [SOffice].[OutlookEmails]')
GO
ALTER TABLE [SOffice].[OutlookEmails] WITH NOCHECK
  ADD CONSTRAINT [FK_OutlookEmails_TargetObjects] FOREIGN KEY ([TargetObjectID]) REFERENCES [SOffice].[TargetObjects] ([ID])
GO

PRINT (N'Create full-text index on table [SOffice].[OutlookEmails]')
GO
CREATE FULLTEXT INDEX
  ON [SOffice].[OutlookEmails]([ToAddresses] LANGUAGE 1033)
  KEY INDEX [PK_OutlookEmails]
  ON [OutlookEmails]
  WITH CHANGE_TRACKING AUTO, STOPLIST SYSTEM
GO