CREATE TABLE [SFin].[SageInboundDocumentStatus]
(
    [ID]                        BIGINT IDENTITY(1,1) NOT NULL,
    [RowStatus]                 TINYINT NOT NULL,
    [RowVersion]                ROWVERSION NOT NULL,
    [Guid]                      UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL,

    [CymBuildEntityTypeID]      INT NOT NULL,
    [CymBuildDocumentGuid]      UNIQUEIDENTIFIER NOT NULL,
    [CymBuildDocumentID]        BIGINT NOT NULL,

    [InvoiceRequestID]          INT NOT NULL DEFAULT (-1),
    [TransactionID]             BIGINT NOT NULL DEFAULT (-1),
    [JobID]                     INT NOT NULL DEFAULT (-1),

    [SageDataset]               NVARCHAR(30) NOT NULL DEFAULT (N''),
    [SageAccountReference]      NVARCHAR(100) NOT NULL DEFAULT (N''),
    [SageDocumentNo]            NVARCHAR(100) NOT NULL DEFAULT (N''),

    [LastOperationName]         NVARCHAR(100) NOT NULL DEFAULT (N'SyncCustomerTransactions'),
    [StatusCode]                NVARCHAR(30) NOT NULL DEFAULT (N'Pending'),
    [IsInProgress]              BIT NOT NULL DEFAULT ((0)),
    [InProgressClaimedOnUtc]    DATETIME2(7) NULL,
    [LastSucceededOnUtc]        DATETIME2(7) NULL,
    [LastFailedOnUtc]           DATETIME2(7) NULL,
    [LastError]                 NVARCHAR(MAX) NULL,
    [LastErrorIsRetryable]      BIT NULL,
    [LastSourceWatermarkUtc]    DATETIME2(7) NULL,

    [CreatedByUserID]           INT NOT NULL DEFAULT (-1),
    [CreatedDateTimeUTC]        DATETIME2(7) NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedByUserID]           INT NOT NULL DEFAULT (-1),
    [UpdatedDateTimeUTC]        DATETIME2(7) NOT NULL DEFAULT (GETUTCDATE()),

    CONSTRAINT [PK_SageInboundDocumentStatus] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [UQ_SageInboundDocumentStatus_Guid] UNIQUE NONCLUSTERED ([Guid])
);
GO