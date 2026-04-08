CREATE OR ALTER PROCEDURE [SFin].[SageInboundPaymentSync_Worklist]
(
    @BatchSize INT = 20,
    @ClaimStaleAfterMinutes INT = 30
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StaleBeforeUtc DATETIME2(7) = DATEADD(MINUTE, -@ClaimStaleAfterMinutes, GETUTCDATE());

    SELECT TOP (@BatchSize)
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
        s.StatusCode,
        s.IsInProgress,
        s.InProgressClaimedOnUtc,
        s.LastSucceededOnUtc,
        s.LastFailedOnUtc,
        s.LastError,
        s.LastErrorIsRetryable
    FROM SFin.SageInboundDocumentStatus AS s
    WHERE s.RowStatus NOT IN (0,254)
      AND
      (
            (
                s.StatusCode IN (N'Pending', N'RetryPending')
                AND s.IsInProgress = 0
            )
            OR
            (
                s.IsInProgress = 1
                AND s.InProgressClaimedOnUtc IS NOT NULL
                AND s.InProgressClaimedOnUtc < @StaleBeforeUtc
            )
      )
    ORDER BY
        CASE s.StatusCode
            WHEN N'Pending' THEN 0
            WHEN N'RetryPending' THEN 1
            ELSE 2
        END,
        ISNULL(s.LastFailedOnUtc, '19000101'),
        s.ID;
END;
GO