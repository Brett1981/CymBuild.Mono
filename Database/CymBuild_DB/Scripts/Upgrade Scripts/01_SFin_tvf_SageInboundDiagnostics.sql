SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
    CYB-214 - Option A
    Read model for inbound Sage payment/allocation diagnostics.

    Notes:
    - Read-only TVF over current status + latest attempt.
    - Uses RowStatus NOT IN (0,254) consistently.
    - Explicit columns only.
    - Deterministic result shape; callers apply ORDER BY explicitly.
*/
CREATE OR ALTER FUNCTION [SFin].[tvf_SageInboundDiagnostics]
(
    @StatusCode NVARCHAR(30) = NULL,
    @SageAccountReference NVARCHAR(100) = NULL,
    @SageDocumentNo NVARCHAR(100) = NULL,
    @OnlyRetryableFailures BIT = NULL,
    @InvoiceRequestID INT = NULL,
    @TransactionID BIGINT = NULL,
    @JobID INT = NULL
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
                WHEN s.StatusCode = N'Failed' THEN 0
                WHEN s.StatusCode = N'RetryPending' THEN 1
                WHEN s.StatusCode = N'Pending' THEN 1
                WHEN s.StatusCode = N'InProgress' THEN 0
                WHEN s.StatusCode = N'Succeeded' THEN 0
                ELSE 0
             END AS BIT) AS CanRequeue,
        CAST(1 AS BIT) AS CanForceRequeue
    FROM SFin.SageInboundDocumentStatus AS s
    LEFT JOIN LatestAttempt AS la
        ON la.InboundStatusID = s.ID
       AND la.RN = 1
    WHERE s.RowStatus NOT IN (0,254)
      AND (@StatusCode IS NULL OR @StatusCode = N'' OR s.StatusCode = @StatusCode)
      AND (@SageAccountReference IS NULL OR @SageAccountReference = N'' OR s.SageAccountReference LIKE N'%' + @SageAccountReference + N'%')
      AND (@SageDocumentNo IS NULL OR @SageDocumentNo = N'' OR s.SageDocumentNo LIKE N'%' + @SageDocumentNo + N'%')
      AND (@OnlyRetryableFailures IS NULL OR ISNULL(s.LastErrorIsRetryable, 0) = @OnlyRetryableFailures)
      AND (@InvoiceRequestID IS NULL OR s.InvoiceRequestID = @InvoiceRequestID)
      AND (@TransactionID IS NULL OR s.TransactionID = @TransactionID)
      AND (@JobID IS NULL OR s.JobID = @JobID)
);
GO
