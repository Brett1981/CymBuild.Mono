PRINT (N'Create table [SFin].[SageInboundDocumentAttempts]')
GO
CREATE TABLE [SFin].[SageInboundDocumentAttempts] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [InboundStatusID] [bigint] NOT NULL,
  [CymBuildDocumentGuid] [uniqueidentifier] NOT NULL,
  [CymBuildDocumentID] [bigint] NOT NULL,
  [OperationName] [nvarchar](100) NOT NULL DEFAULT (N'SyncCustomerTransactions'),
  [AttemptedOnUtc] [datetime2] NOT NULL,
  [CompletedOnUtc] [datetime2] NULL,
  [IsSuccess] [bit] NOT NULL DEFAULT (0),
  [IsRetryableFailure] [bit] NOT NULL DEFAULT (0),
  [ResponseStatus] [nvarchar](50) NOT NULL DEFAULT (N''),
  [ResponseDetail] [nvarchar](max) NULL,
  [ErrorMessage] [nvarchar](max) NULL,
  [RequestPayloadJson] [nvarchar](max) NULL,
  [ResponsePayloadJson] [nvarchar](max) NULL,
  [CreatedByUserID] [int] NOT NULL DEFAULT (-1),
  [CreatedDateTimeUTC] [datetime2] NOT NULL DEFAULT (getutcdate())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SageInboundDocumentAttempts] on table [SFin].[SageInboundDocumentAttempts]')
GO
ALTER TABLE [SFin].[SageInboundDocumentAttempts] WITH NOCHECK
  ADD CONSTRAINT [PK_SageInboundDocumentAttempts] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_SageInboundDocumentAttempts_Guid] on table [SFin].[SageInboundDocumentAttempts]')
GO
ALTER TABLE [SFin].[SageInboundDocumentAttempts] WITH NOCHECK
  ADD CONSTRAINT [UQ_SageInboundDocumentAttempts_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_SageInboundDocumentAttempts_InboundStatusID_AttemptedOnUtc] on table [SFin].[SageInboundDocumentAttempts]')
GO
CREATE INDEX [IX_SageInboundDocumentAttempts_InboundStatusID_AttemptedOnUtc]
  ON [SFin].[SageInboundDocumentAttempts] ([InboundStatusID], [AttemptedOnUtc] DESC, [ID] DESC)
  INCLUDE ([CompletedOnUtc], [IsSuccess], [IsRetryableFailure], [ErrorMessage], [ResponseStatus], [ResponseDetail])
  WITH (PAD_INDEX = ON, FILLFACTOR = 80)
  ON [PRIMARY]
GO