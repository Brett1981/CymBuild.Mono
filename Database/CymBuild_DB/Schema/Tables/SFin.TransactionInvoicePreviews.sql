PRINT (N'Create table [SFin].[TransactionInvoicePreviews]')
GO
CREATE TABLE [SFin].[TransactionInvoicePreviews] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_TransactionInvoicePreviews_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_TransactionInvoicePreviews_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [TransactionId] [bigint] NOT NULL,
  [MergeDocumentId] [int] NOT NULL,
  [InvoiceNumberReserved] [nvarchar](30) NOT NULL,
  [SharePointDriveId] [nvarchar](200) NOT NULL,
  [SharePointItemId] [nvarchar](200) NOT NULL,
  [SharePointWebUrl] [nvarchar](1000) NOT NULL,
  [Filename] [nvarchar](260) NOT NULL,
  [MimeType] [nvarchar](100) NOT NULL,
  [FileHash] [nvarchar](128) NOT NULL,
  [SourceTransactionRowVersion] [varbinary](8) NOT NULL,
  [GeneratedByUserId] [int] NOT NULL,
  [GeneratedDateTimeUtc] [datetime2] NOT NULL CONSTRAINT [DF_TransactionInvoicePreviews_GeneratedDate] DEFAULT (sysutcdatetime()),
  [IsCurrent] [bit] NOT NULL CONSTRAINT [DF_TransactionInvoicePreviews_IsCurrent] DEFAULT (1),
  [IsPostedToSage] [bit] NOT NULL CONSTRAINT [DF_TransactionInvoicePreviews_IsPostedToSage] DEFAULT (0),
  [PostedToSageDateTimeUtc] [datetime2] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_TransactionInvoicePreviews] on table [SFin].[TransactionInvoicePreviews]')
GO
ALTER TABLE [SFin].[TransactionInvoicePreviews] WITH NOCHECK
  ADD CONSTRAINT [PK_TransactionInvoicePreviews] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_TransactionInvoicePreviews_Guid] on table [SFin].[TransactionInvoicePreviews]')
GO
ALTER TABLE [SFin].[TransactionInvoicePreviews] WITH NOCHECK
  ADD CONSTRAINT [UQ_TransactionInvoicePreviews_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_TransactionInvoicePreviews_Transaction_Current] on table [SFin].[TransactionInvoicePreviews]')
GO
CREATE INDEX [IX_TransactionInvoicePreviews_Transaction_Current]
  ON [SFin].[TransactionInvoicePreviews] ([TransactionId], [IsCurrent])
  INCLUDE ([InvoiceNumberReserved], [SharePointItemId], [SharePointWebUrl], [GeneratedDateTimeUtc], [SourceTransactionRowVersion], [IsPostedToSage])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_TransactionInvoicePreviews_DataObjects] on table [SFin].[TransactionInvoicePreviews]')
GO
ALTER TABLE [SFin].[TransactionInvoicePreviews] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionInvoicePreviews_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_TransactionInvoicePreviews_DataObjects] on table [SFin].[TransactionInvoicePreviews]')
GO
ALTER TABLE [SFin].[TransactionInvoicePreviews]
  NOCHECK CONSTRAINT [FK_TransactionInvoicePreviews_DataObjects]
GO

PRINT (N'Create foreign key [FK_TransactionInvoicePreviews_Identities] on table [SFin].[TransactionInvoicePreviews]')
GO
ALTER TABLE [SFin].[TransactionInvoicePreviews] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionInvoicePreviews_Identities] FOREIGN KEY ([GeneratedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionInvoicePreviews_MergeDocuments] on table [SFin].[TransactionInvoicePreviews]')
GO
ALTER TABLE [SFin].[TransactionInvoicePreviews] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionInvoicePreviews_MergeDocuments] FOREIGN KEY ([MergeDocumentId]) REFERENCES [SCore].[MergeDocuments] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionInvoicePreviews_RowStatus] on table [SFin].[TransactionInvoicePreviews]')
GO
ALTER TABLE [SFin].[TransactionInvoicePreviews] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionInvoicePreviews_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionInvoicePreviews_Transactions] on table [SFin].[TransactionInvoicePreviews]')
GO
ALTER TABLE [SFin].[TransactionInvoicePreviews] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionInvoicePreviews_Transactions] FOREIGN KEY ([TransactionId]) REFERENCES [SFin].[Transactions] ([ID])
GO