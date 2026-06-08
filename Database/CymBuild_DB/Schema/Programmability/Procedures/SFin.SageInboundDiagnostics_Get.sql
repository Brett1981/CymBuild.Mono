SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageInboundDiagnostics_Get]')
GO

CREATE PROCEDURE [SFin].[SageInboundDiagnostics_Get]
(
    @StatusCode NVARCHAR(30) = NULL,
    @SageAccountReference NVARCHAR(100) = NULL,
    @SageDocumentNo NVARCHAR(100) = NULL,
    @TransactionNumber NVARCHAR(50) = NULL,
    @OnlyRetryableFailures BIT = NULL,
    @InvoiceRequestID INT = NULL,
    @TransactionID BIGINT = NULL,
    @JobID INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.ID,
        d.Guid,
        d.CymBuildEntityTypeID,
        d.CymBuildDocumentGuid,
        d.CymBuildDocumentID,
        d.InvoiceRequestID,
        d.TransactionID,
        d.JobID,
        d.SageDataset,
        d.SageAccountReference,
        d.SageDocumentNo,
        d.LastOperationName,
        d.StatusCode,
        d.IsInProgress,
        d.InProgressClaimedOnUtc,
        d.LastSucceededOnUtc,
        d.LastFailedOnUtc,
        d.LastError,
        d.LastErrorIsRetryable,
        d.LastSourceWatermarkUtc,
        d.LastGrossAmount,
        d.LastAllocatedValue,
        d.LastOutstandingAmount,
        d.LastDocumentDiscountedValue,
        d.LastIsPaid,
        d.LastIsFullyPaid,
        d.LastPaymentStateCode,
        d.LastTransactionDate,
        d.LastSageTransactionReference,
        d.LastSecondReference,
        d.LastSageTransactionTypeCode,
        d.NextPollDueOnUtc,
        d.PollAttemptCount,
        d.IsTerminalState,
        d.CreatedByUserID,
        d.CreatedDateTimeUTC,
        d.UpdatedByUserID,
        d.UpdatedDateTimeUTC,
        d.LastAttemptedOnUtc,
        d.LastCompletedOnUtc,
        d.LastAttemptIsSuccess,
        d.LastAttemptErrorMessage,
        d.LastAttemptIsRetryableFailure,
        d.LastAttemptResponseStatus,
        d.LastAttemptResponseDetail,
        d.CanRequeue,
        d.CanForceRequeue,

        d.TransactionGuid,
        d.TransactionNumber,
        d.TransactionIsBatched,
        d.MatchedTransactionGuid,
        d.MatchedTransactionNumber,
        d.MaterialisedReceiptTransactionGuid,
        d.MaterialisedReceiptTransactionNumber,
        d.MaterialisedAllocationGuid,
        d.MaterialisedAllocationID
    FROM SFin.tvf_SageInboundDiagnostics
    (
        @StatusCode,
        @SageAccountReference,
        @SageDocumentNo,
        @OnlyRetryableFailures,
        @InvoiceRequestID,
        @TransactionID,
        @JobID,
        @TransactionNumber
    ) AS d
    ORDER BY d.UpdatedDateTimeUTC DESC, d.ID DESC;
END
GO