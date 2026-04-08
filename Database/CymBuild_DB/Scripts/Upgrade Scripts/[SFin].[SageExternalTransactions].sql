CREATE TABLE [SFin].[SageExternalTransactions]
(
    [ID]                       BIGINT IDENTITY(1,1) NOT NULL,
    [RowStatus]                TINYINT NOT NULL,
    [RowVersion]               ROWVERSION NOT NULL,
    [Guid]                     UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL,

    [SageDataset]              NVARCHAR(30) NOT NULL DEFAULT (N''),
    [SageAccountReference]     NVARCHAR(100) NOT NULL DEFAULT (N''),
    [SageDocumentNo]           NVARCHAR(100) NOT NULL DEFAULT (N''),
    [SageTransactionReference] NVARCHAR(100) NOT NULL DEFAULT (N''),
    [SecondReference]          NVARCHAR(100) NOT NULL DEFAULT (N''),
    [SageTransactionTypeCode]  INT NOT NULL, -- 4 invoice, 5 credit note, 6 receipt

    [TransactionDate]          DATE NULL,
    [NetAmount]                DECIMAL(18,2) NOT NULL DEFAULT ((0)),
    [TaxAmount]                DECIMAL(18,2) NOT NULL DEFAULT ((0)),
    [GrossAmount]              DECIMAL(18,2) NOT NULL DEFAULT ((0)),
    [OutstandingAmount]        DECIMAL(18,2) NOT NULL DEFAULT ((0)),

    [MatchedTransactionID]     BIGINT NOT NULL DEFAULT (-1),
    [MatchedInvoiceRequestID]  INT NOT NULL DEFAULT (-1),
    [MatchedJobID]             INT NOT NULL DEFAULT (-1),

    [SourceHash]               NVARCHAR(128) NOT NULL DEFAULT (N''),
    [LastSeenOnUtc]            DATETIME2(7) NOT NULL DEFAULT (GETUTCDATE()),
    [RawPayloadJson]           NVARCHAR(MAX) NULL,

    [CreatedByUserID]          INT NOT NULL DEFAULT (-1),
    [CreatedDateTimeUTC]       DATETIME2(7) NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedByUserID]          INT NOT NULL DEFAULT (-1),
    [UpdatedDateTimeUTC]       DATETIME2(7) NOT NULL DEFAULT (GETUTCDATE()),

    CONSTRAINT [PK_SageExternalTransactions] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [UQ_SageExternalTransactions_Guid] UNIQUE NONCLUSTERED ([Guid])
);
GO