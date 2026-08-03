PRINT (N'Create table [SFin].[SageInboundDocumentStatus]')
GO
PRINT (N'Create table [SFin].[SageInboundDocumentStatus]')
GO
CREATE TABLE [SFin].[SageInboundDocumentStatus] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [CymBuildEntityTypeID] [int] NOT NULL,
  [CymBuildDocumentGuid] [uniqueidentifier] NOT NULL,
  [CymBuildDocumentID] [bigint] NOT NULL,
  [InvoiceRequestID] [int] NOT NULL DEFAULT (-1),
  [TransactionID] [bigint] NOT NULL DEFAULT (-1),
  [JobID] [int] NOT NULL DEFAULT (-1),
  [SageDataset] [nvarchar](30) NOT NULL DEFAULT (N''),
  [SageAccountReference] [nvarchar](100) NOT NULL DEFAULT (N''),
  [SageDocumentNo] [nvarchar](100) NOT NULL DEFAULT (N''),
  [LastOperationName] [nvarchar](100) NOT NULL DEFAULT (N'SyncCustomerTransactions'),
  [StatusCode] [nvarchar](30) NOT NULL DEFAULT (N'Pending'),
  [IsInProgress] [bit] NOT NULL DEFAULT (0),
  [InProgressClaimedOnUtc] [datetime2] NULL,
  [LastSucceededOnUtc] [datetime2] NULL,
  [LastFailedOnUtc] [datetime2] NULL,
  [LastError] [nvarchar](max) NULL,
  [LastErrorIsRetryable] [bit] NULL,
  [LastSourceWatermarkUtc] [datetime2] NULL,
  [CreatedByUserID] [int] NOT NULL DEFAULT (-1),
  [CreatedDateTimeUTC] [datetime2] NOT NULL DEFAULT (getutcdate()),
  [UpdatedByUserID] [int] NOT NULL DEFAULT (-1),
  [UpdatedDateTimeUTC] [datetime2] NOT NULL DEFAULT (getutcdate()),
  [LastGrossAmount] [decimal](18, 2) NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_LastGrossAmount] DEFAULT (0),
  [LastAllocatedValue] [decimal](18, 2) NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_LastAllocatedValue] DEFAULT (0),
  [LastOutstandingAmount] [decimal](18, 2) NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_LastOutstandingAmount] DEFAULT (0),
  [LastDocumentDiscountedValue] [decimal](18, 2) NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_LastDocumentDiscountedValue] DEFAULT (0),
  [LastIsPaid] [bit] NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_LastIsPaid] DEFAULT (0),
  [LastIsFullyPaid] [bit] NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_LastIsFullyPaid] DEFAULT (0),
  [LastPaymentStateCode] [nvarchar](30) NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_LastPaymentStateCode] DEFAULT (N'Unknown'),
  [LastTransactionDate] [date] NULL,
  [LastSageTransactionReference] [nvarchar](100) NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_LastSageTransactionReference] DEFAULT (N''),
  [LastSecondReference] [nvarchar](100) NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_LastSecondReference] DEFAULT (N''),
  [LastSageTransactionTypeCode] [int] NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_LastSageTransactionTypeCode] DEFAULT (-1),
  [NextPollDueOnUtc] [datetime2] NULL,
  [PollAttemptCount] [int] NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_PollAttemptCount] DEFAULT (0),
  [IsTerminalState] [bit] NOT NULL CONSTRAINT [DF_SageInboundDocumentStatus_IsTerminalState] DEFAULT (0)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SageInboundDocumentStatus] on table [SFin].[SageInboundDocumentStatus]')
GO
ALTER TABLE [SFin].[SageInboundDocumentStatus] WITH NOCHECK
  ADD CONSTRAINT [PK_SageInboundDocumentStatus] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_SageInboundDocumentStatus_Guid] on table [SFin].[SageInboundDocumentStatus]')
GO
ALTER TABLE [SFin].[SageInboundDocumentStatus] WITH NOCHECK
  ADD CONSTRAINT [UQ_SageInboundDocumentStatus_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_SageInboundDocumentStatus_CymBuildDocumentGuid] on table [SFin].[SageInboundDocumentStatus]')
GO
CREATE INDEX [IX_SageInboundDocumentStatus_CymBuildDocumentGuid]
  ON [SFin].[SageInboundDocumentStatus] ([CymBuildDocumentGuid])
  INCLUDE ([StatusCode], [IsInProgress], [InProgressClaimedOnUtc], [InvoiceRequestID], [TransactionID], [JobID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SageInboundDocumentStatus_Worklist] on table [SFin].[SageInboundDocumentStatus]')
GO
CREATE INDEX [IX_SageInboundDocumentStatus_Worklist]
  ON [SFin].[SageInboundDocumentStatus] ([RowStatus], [IsTerminalState], [IsInProgress], [NextPollDueOnUtc], [StatusCode])
  INCLUDE ([CymBuildDocumentGuid], [InvoiceRequestID], [TransactionID], [JobID], [SageDataset], [SageAccountReference], [SageDocumentNo], [LastOutstandingAmount], [LastAllocatedValue], [LastIsPaid], [LastIsFullyPaid], [LastPaymentStateCode])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO


PRINT (N'Create index [IX_SageInboundDocumentStatus_CymBuildDocumentGuid] on table [SFin].[SageInboundDocumentStatus]')
GO


PRINT (N'Create index [IX_SageInboundDocumentStatus_Worklist] on table [SFin].[SageInboundDocumentStatus]')
GO