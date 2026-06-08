SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SFin].[vw_SageInboundDiagnostics]')
GO

    CREATE VIEW [SFin].[vw_SageInboundDiagnostics]
    AS
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
        d.CanForceRequeue
    FROM SFin.tvf_SageInboundDiagnostics(DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS d;
    
GO