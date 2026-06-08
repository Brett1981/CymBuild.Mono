ALTER FUNCTION [SFin].[tvf_SageInboundDiagnostics]
(
    @StatusCode NVARCHAR(30) = NULL,
    @SageAccountReference NVARCHAR(100) = NULL,
    @SageDocumentNo NVARCHAR(100) = NULL,
    @OnlyRetryableFailures BIT = NULL,
    @InvoiceRequestID INT = NULL,
    @TransactionID BIGINT = NULL,
    @JobID INT = NULL,
    @TransactionNumber NVARCHAR(50) = NULL
)
RETURNS TABLE
AS
RETURN
(
    WITH LatestAttempt AS
    (
        SELECT
            a.InboundStatusID,
            a.AttemptedOnUtc,
            a.CompletedOnUtc,
            a.IsSuccess,
            a.ErrorMessage,
            a.IsRetryableFailure,
            a.ResponseStatus,
            a.ResponseDetail,
            ROW_NUMBER() OVER
            (
                PARTITION BY a.InboundStatusID
                ORDER BY a.AttemptedOnUtc DESC, a.ID DESC
            ) AS RN
        FROM SFin.SageInboundDocumentAttempts AS a
        WHERE a.RowStatus NOT IN (0,254)
    )
    SELECT
        s.ID,
        s.Guid,
        s.CymBuildEntityTypeID,
        s.CymBuildDocumentGuid,
        s.CymBuildDocumentID,
        s.InvoiceRequestID,
        s.TransactionID,
        s.JobID,
        s.SageDataset,
        s.SageAccountReference,
        s.SageDocumentNo,
        s.LastOperationName,
        s.StatusCode,
        s.IsInProgress,
        s.InProgressClaimedOnUtc,
        s.LastSucceededOnUtc,
        s.LastFailedOnUtc,
        s.LastError,
        s.LastErrorIsRetryable,
        s.LastSourceWatermarkUtc,
        s.LastGrossAmount,
        s.LastAllocatedValue,
        s.LastOutstandingAmount,
        s.LastDocumentDiscountedValue,
        s.LastIsPaid,
        s.LastIsFullyPaid,
        s.LastPaymentStateCode,
        s.LastTransactionDate,
        s.LastSageTransactionReference,
        s.LastSecondReference,
        s.LastSageTransactionTypeCode,
        s.NextPollDueOnUtc,
        s.PollAttemptCount,
        s.IsTerminalState,
        s.CreatedByUserID,
        s.CreatedDateTimeUTC,
        s.UpdatedByUserID,
        s.UpdatedDateTimeUTC,

        la.AttemptedOnUtc AS LastAttemptedOnUtc,
        la.CompletedOnUtc AS LastCompletedOnUtc,
        la.IsSuccess AS LastAttemptIsSuccess,
        la.ErrorMessage AS LastAttemptErrorMessage,
        la.IsRetryableFailure AS LastAttemptIsRetryableFailure,
        la.ResponseStatus AS LastAttemptResponseStatus,
        la.ResponseDetail AS LastAttemptResponseDetail,

        CAST(CASE
                WHEN s.IsTerminalState = 1 THEN 0
                WHEN s.StatusCode = N'Failed' THEN 0
                WHEN s.StatusCode = N'RetryPending' THEN 1
                WHEN s.StatusCode = N'Pending' THEN 1
                WHEN s.StatusCode = N'PartiallyPaid' THEN 1
                WHEN s.StatusCode = N'InProgress' THEN 0
                WHEN s.StatusCode = N'Succeeded' THEN 0
                ELSE 0
             END AS BIT) AS CanRequeue,

        CAST(1 AS BIT) AS CanForceRequeue,

        srcTran.Guid AS TransactionGuid,
        ISNULL(srcTran.Number, N'') AS TransactionNumber,
        CAST(ISNULL(srcTran.Batched, 0) AS BIT) AS TransactionIsBatched,

        matchedTran.Guid AS MatchedTransactionGuid,
        ISNULL(matchedTran.Number, N'') AS MatchedTransactionNumber,

        receiptTran.Guid AS MaterialisedReceiptTransactionGuid,
        ISNULL(receiptTran.Number, N'') AS MaterialisedReceiptTransactionNumber,

        alloc.Guid AS MaterialisedAllocationGuid,
        alloc.ID AS MaterialisedAllocationID

    FROM SFin.SageInboundDocumentStatus AS s
    LEFT JOIN LatestAttempt AS la
        ON la.InboundStatusID = s.ID
       AND la.RN = 1

    OUTER APPLY
    (
        SELECT TOP (1)
            ext.ID,
            ext.Guid,
            ext.MatchedTransactionID,
            ext.MatchedInvoiceRequestID,
            ext.MatchedJobID,
            ext.MaterialisedReceiptTransactionID,
            ext.MaterialisedReceiptTransactionGuid,
            ext.MaterialisedAllocationID,
            ext.MaterialisedAllocationGuid
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.RowStatus NOT IN (0,254)
          AND
          (
                (
                    ext.SageDataset = s.SageDataset
                AND ext.SageAccountReference = s.SageAccountReference
                AND ext.SageDocumentNo = s.SageDocumentNo
                )
             OR (
                    ext.MatchedTransactionID = s.TransactionID
                AND s.TransactionID > 0
                )
             OR (
                    ext.MatchedInvoiceRequestID = s.InvoiceRequestID
                AND s.InvoiceRequestID > 0
                )
          )
        ORDER BY
            CASE
                WHEN ext.MatchedTransactionID = s.TransactionID
                     AND s.TransactionID > 0 THEN 0
                WHEN ext.MatchedInvoiceRequestID = s.InvoiceRequestID
                     AND s.InvoiceRequestID > 0 THEN 1
                WHEN ext.SageDataset = s.SageDataset
                 AND ext.SageAccountReference = s.SageAccountReference
                 AND ext.SageDocumentNo = s.SageDocumentNo THEN 2
                ELSE 9
            END,
            ext.LastSeenOnUtc DESC,
            ext.ID DESC
    ) AS ext

    LEFT JOIN SFin.Transactions AS srcTran
        ON srcTran.ID = s.TransactionID
       AND srcTran.RowStatus NOT IN (0,254)

    LEFT JOIN SFin.Transactions AS matchedTran
        ON matchedTran.ID = ext.MatchedTransactionID
       AND matchedTran.RowStatus NOT IN (0,254)

    LEFT JOIN SFin.Transactions AS receiptTran
        ON receiptTran.ID = ext.MaterialisedReceiptTransactionID
       AND receiptTran.RowStatus NOT IN (0,254)

    LEFT JOIN SFin.TransactionAllocations AS alloc
        ON alloc.ID = ext.MaterialisedAllocationID
       AND alloc.RowStatus NOT IN (0,254)

    WHERE s.RowStatus NOT IN (0,254)
      AND (@StatusCode IS NULL OR @StatusCode = N'' OR s.StatusCode = @StatusCode)
      AND (@SageAccountReference IS NULL OR @SageAccountReference = N'' OR s.SageAccountReference LIKE N'%' + @SageAccountReference + N'%')
      AND (@SageDocumentNo IS NULL OR @SageDocumentNo = N'' OR s.SageDocumentNo LIKE N'%' + @SageDocumentNo + N'%')
      AND (@OnlyRetryableFailures IS NULL OR ISNULL(s.LastErrorIsRetryable, 0) = @OnlyRetryableFailures)
      AND (@InvoiceRequestID IS NULL OR s.InvoiceRequestID = @InvoiceRequestID)
      AND (@TransactionID IS NULL OR s.TransactionID = @TransactionID)
      AND (@JobID IS NULL OR s.JobID = @JobID)
      AND
      (
            @TransactionNumber IS NULL
         OR @TransactionNumber = N''
         OR ISNULL(srcTran.Number, N'') LIKE N'%' + @TransactionNumber + N'%'
         OR ISNULL(matchedTran.Number, N'') LIKE N'%' + @TransactionNumber + N'%'
         OR ISNULL(receiptTran.Number, N'') LIKE N'%' + @TransactionNumber + N'%'
      )
);
GO