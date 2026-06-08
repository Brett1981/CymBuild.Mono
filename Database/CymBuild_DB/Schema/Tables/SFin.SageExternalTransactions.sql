PRINT (N'Create table [SFin].[SageExternalTransactions]')
GO
CREATE TABLE [SFin].[SageExternalTransactions] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [SageDataset] [nvarchar](30) NOT NULL DEFAULT (N''),
  [SageAccountReference] [nvarchar](100) NOT NULL DEFAULT (N''),
  [SageDocumentNo] [nvarchar](100) NOT NULL DEFAULT (N''),
  [SageTransactionReference] [nvarchar](100) NOT NULL DEFAULT (N''),
  [SecondReference] [nvarchar](100) NOT NULL DEFAULT (N''),
  [SageTransactionTypeCode] [int] NOT NULL,
  [TransactionDate] [date] NULL,
  [NetAmount] [decimal](18, 2) NOT NULL DEFAULT (0),
  [TaxAmount] [decimal](18, 2) NOT NULL DEFAULT (0),
  [GrossAmount] [decimal](18, 2) NOT NULL DEFAULT (0),
  [OutstandingAmount] [decimal](18, 2) NOT NULL DEFAULT (0),
  [MatchedTransactionID] [bigint] NOT NULL DEFAULT (-1),
  [MatchedInvoiceRequestID] [int] NOT NULL DEFAULT (-1),
  [MatchedJobID] [int] NOT NULL DEFAULT (-1),
  [SourceHash] [nvarchar](128) NOT NULL DEFAULT (N''),
  [LastSeenOnUtc] [datetime2] NOT NULL DEFAULT (getutcdate()),
  [RawPayloadJson] [nvarchar](max) NULL,
  [CreatedByUserID] [int] NOT NULL DEFAULT (-1),
  [CreatedDateTimeUTC] [datetime2] NOT NULL DEFAULT (getutcdate()),
  [UpdatedByUserID] [int] NOT NULL DEFAULT (-1),
  [UpdatedDateTimeUTC] [datetime2] NOT NULL DEFAULT (getutcdate()),
  [AllocatedValue] [decimal](18, 2) NOT NULL CONSTRAINT [DF_SageExternalTransactions_AllocatedValue] DEFAULT (0),
  [DocumentDiscountedValue] [decimal](18, 2) NOT NULL CONSTRAINT [DF_SageExternalTransactions_DocumentDiscountedValue] DEFAULT (0),
  [IsPaid] [bit] NOT NULL CONSTRAINT [DF_SageExternalTransactions_IsPaid] DEFAULT (0),
  [IsFullyPaid] [bit] NOT NULL CONSTRAINT [DF_SageExternalTransactions_IsFullyPaid] DEFAULT (0),
  [PaymentStateCode] [nvarchar](30) NOT NULL CONSTRAINT [DF_SageExternalTransactions_PaymentStateCode] DEFAULT (N'Unknown'),
  [MaterialisedReceiptTransactionID] [bigint] NULL,
  [MaterialisedReceiptTransactionGuid] [uniqueidentifier] NULL,
  [MaterialisedAllocationID] [bigint] NULL,
  [MaterialisedAllocationGuid] [uniqueidentifier] NULL,
  [ReceiptMaterialisedOnUtc] [datetime2] NULL,
  [ReceiptMaterialisationError] [nvarchar](2000) NOT NULL CONSTRAINT [DF_SageExternalTransactions_ReceiptMaterialisationError] DEFAULT (N'')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SageExternalTransactions] on table [SFin].[SageExternalTransactions]')
GO
ALTER TABLE [SFin].[SageExternalTransactions] WITH NOCHECK
  ADD CONSTRAINT [PK_SageExternalTransactions] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_SageExternalTransactions_Guid] on table [SFin].[SageExternalTransactions]')
GO
ALTER TABLE [SFin].[SageExternalTransactions] WITH NOCHECK
  ADD CONSTRAINT [UQ_SageExternalTransactions_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_SageExternalTransactions_NaturalKey_Active] on table [SFin].[SageExternalTransactions]')
GO
CREATE UNIQUE INDEX [UX_SageExternalTransactions_NaturalKey_Active]
  ON [SFin].[SageExternalTransactions] ([SageDataset], [SageAccountReference], [SageTransactionTypeCode], [SageDocumentNo], [SageTransactionReference])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO