/*
    Supporting indexes for diagnostics and latest-attempt retrieval.
*/
CREATE NONCLUSTERED INDEX [IX_SageInboundDocumentStatus_Diagnostics]
ON [SFin].[SageInboundDocumentStatus]
(
    [StatusCode] ASC,
    [IsInProgress] ASC,
    [SageAccountReference] ASC,
    [SageDocumentNo] ASC
)
INCLUDE
(
    [CymBuildDocumentGuid],
    [InvoiceRequestID],
    [TransactionID],
    [JobID],
    [LastSucceededOnUtc],
    [LastFailedOnUtc],
    [LastErrorIsRetryable],
    [UpdatedDateTimeUTC]
);
GO

CREATE NONCLUSTERED INDEX [IX_SageInboundDocumentStatus_CymBuildDocumentGuid]
ON [SFin].[SageInboundDocumentStatus]
(
    [CymBuildDocumentGuid] ASC
)
INCLUDE
(
    [StatusCode],
    [IsInProgress],
    [InProgressClaimedOnUtc],
    [InvoiceRequestID],
    [TransactionID],
    [JobID]
);
GO

CREATE NONCLUSTERED INDEX [IX_SageInboundDocumentAttempts_InboundStatusID_AttemptedOnUtc]
ON [SFin].[SageInboundDocumentAttempts]
(
    [InboundStatusID] ASC,
    [AttemptedOnUtc] DESC,
    [ID] DESC
)
INCLUDE
(
    [CompletedOnUtc],
    [IsSuccess],
    [IsRetryableFailure],
    [ErrorMessage],
    [ResponseStatus],
    [ResponseDetail]
);
GO
