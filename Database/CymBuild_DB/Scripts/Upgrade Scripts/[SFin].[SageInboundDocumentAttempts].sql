CREATE TABLE [SFin].[SageInboundDocumentAttempts]
(
    [ID]                     BIGINT IDENTITY(1,1) NOT NULL,
    [RowStatus]              TINYINT NOT NULL,
    [RowVersion]             ROWVERSION NOT NULL,
    [Guid]                   UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL,

    [InboundStatusID]        BIGINT NOT NULL,
    [CymBuildDocumentGuid]   UNIQUEIDENTIFIER NOT NULL,
    [CymBuildDocumentID]     BIGINT NOT NULL,

    [OperationName]          NVARCHAR(100) NOT NULL DEFAULT (N'SyncCustomerTransactions'),
    [AttemptedOnUtc]         DATETIME2(7) NOT NULL,
    [CompletedOnUtc]         DATETIME2(7) NULL,
    [IsSuccess]              BIT NOT NULL DEFAULT ((0)),
    [IsRetryableFailure]     BIT NOT NULL DEFAULT ((0)),
    [ResponseStatus]         NVARCHAR(50) NOT NULL DEFAULT (N''),
    [ResponseDetail]         NVARCHAR(MAX) NULL,
    [ErrorMessage]           NVARCHAR(MAX) NULL,
    [RequestPayloadJson]     NVARCHAR(MAX) NULL,
    [ResponsePayloadJson]    NVARCHAR(MAX) NULL,

    [CreatedByUserID]        INT NOT NULL DEFAULT (-1),
    [CreatedDateTimeUTC]     DATETIME2(7) NOT NULL DEFAULT (GETUTCDATE()),

    CONSTRAINT [PK_SageInboundDocumentAttempts] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [UQ_SageInboundDocumentAttempts_Guid] UNIQUE NONCLUSTERED ([Guid])
);
GO