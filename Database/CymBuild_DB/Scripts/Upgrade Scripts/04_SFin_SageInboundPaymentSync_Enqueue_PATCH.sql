SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
    CYB-214 - Option A
    Manual/admin requeue semantics.

    Behaviour:
    - Requeue (ForceRequeue = 0):
        * allowed for Pending / Failed / RetryPending / stale in-progress rows.
        * clears stuck in-progress state safely.
        * does not overwrite success history.
        * does not reset Succeeded rows.
    - Force Requeue (ForceRequeue = 1):
        * allowed for any row.
        * clears in-progress state and returns row to Pending.
    - Audit history is preserved because attempts/history rows are never deleted.
*/
CREATE OR ALTER PROCEDURE [SFin].[SageInboundPaymentSync_Enqueue]
(
    @CymBuildDocumentGuid UNIQUEIDENTIFIER,
    @ForceRequeue BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @InvoiceRequestID       INT = -1,
        @TransactionID          BIGINT = -1,
        @JobID                  INT = -1,
        @CymBuildDocumentID     BIGINT = -1,
        @CymBuildEntityTypeID   INT = -1,
        @SageDataset            NVARCHAR(30) = N'LIVE',
        @SageAccountReference   NVARCHAR(100) = N'',
        @SageDocumentNo         NVARCHAR(100) = N'',
        @StatusGuid             UNIQUEIDENTIFIER = NULL,
        @ExistingStatusCode     NVARCHAR(30) = NULL,
        @ExistingIsInProgress   BIT = 0,
        @NowUtc                 DATETIME2(7) = GETUTCDATE();

    SELECT TOP (1)
        @InvoiceRequestID     = ir.ID,
        @CymBuildDocumentID   = ir.ID,
        @TransactionID        = ISNULL(t.ID, -1),
        @JobID                = ISNULL(ir.JobId, -1),
        @SageAccountReference = ISNULL(a.Code, N''),
        @SageDocumentNo       = ISNULL(t.Number, N'')
    FROM SFin.InvoiceRequests AS ir
    LEFT JOIN SFin.InvoiceRequestItems AS iri
        ON iri.InvoiceRequestId = ir.ID
       AND iri.RowStatus NOT IN (0,254)
    LEFT JOIN SFin.TransactionDetails AS td
        ON td.InvoiceRequestItemId = iri.ID
       AND td.RowStatus NOT IN (0,254)
    LEFT JOIN SFin.Transactions AS t
        ON t.ID = td.TransactionID
       AND t.RowStatus NOT IN (0,254)
    LEFT JOIN SCrm.Accounts AS a
        ON a.ID = t.AccountID
       AND a.RowStatus NOT IN (0,254)
    WHERE ir.Guid = @CymBuildDocumentGuid
      AND ir.RowStatus NOT IN (0,254)
    ORDER BY t.ID DESC, iri.ID DESC;

    IF @InvoiceRequestID <= 0
    BEGIN
        RAISERROR('No active InvoiceRequest could be resolved for the supplied CymBuildDocumentGuid.', 16, 1);
        RETURN;
    END;

    SELECT TOP (1)
        @CymBuildEntityTypeID = et.ID
    FROM SCore.EntityTypes AS et
    WHERE et.RowStatus NOT IN (0,254)
      AND et.Name IN (N'Invoice Requests', N'Invoice Request')
    ORDER BY et.ID;

    IF @CymBuildEntityTypeID <= 0
    BEGIN
        RAISERROR('Unable to resolve EntityTypeId for Invoice Requests.', 16, 1);
        RETURN;
    END;

    SELECT TOP (1)
        @ExistingStatusCode = s.StatusCode,
        @ExistingIsInProgress = s.IsInProgress,
        @StatusGuid = s.Guid
    FROM SFin.SageInboundDocumentStatus AS s
    WHERE s.CymBuildDocumentGuid = @CymBuildDocumentGuid
      AND s.RowStatus NOT IN (0,254)
    ORDER BY s.ID DESC;

    IF @StatusGuid IS NULL
    BEGIN
        EXEC [SFin].[SageInboundDocumentStatus_Ensure]
             @CymBuildEntityTypeID = @CymBuildEntityTypeID,
             @CymBuildDocumentGuid = @CymBuildDocumentGuid,
             @CymBuildDocumentID   = @CymBuildDocumentID,
             @InvoiceRequestID     = @InvoiceRequestID,
             @TransactionID        = @TransactionID,
             @JobID                = @JobID,
             @SageDataset          = @SageDataset,
             @SageAccountReference = @SageAccountReference,
             @SageDocumentNo       = @SageDocumentNo,
             @Guid                 = @StatusGuid OUTPUT;
    END
    ELSE
    BEGIN
        UPDATE s
        SET
            InvoiceRequestID       = @InvoiceRequestID,
            TransactionID          = @TransactionID,
            JobID                  = @JobID,
            CymBuildDocumentID     = @CymBuildDocumentID,
            CymBuildEntityTypeID   = @CymBuildEntityTypeID,
            SageDataset            = @SageDataset,
            SageAccountReference   = @SageAccountReference,
            SageDocumentNo         = @SageDocumentNo,
            StatusCode             = CASE
                                        WHEN @ForceRequeue = 1 THEN N'Pending'
                                        WHEN @ExistingStatusCode IN (N'Pending', N'Failed', N'RetryPending') THEN N'Pending'
                                        WHEN @ExistingIsInProgress = 1 THEN N'Pending'
                                        ELSE @ExistingStatusCode
                                     END,
            IsInProgress           = CASE
                                        WHEN @ForceRequeue = 1 THEN 0
                                        WHEN @ExistingStatusCode IN (N'Pending', N'Failed', N'RetryPending') THEN 0
                                        WHEN @ExistingIsInProgress = 1 THEN 0
                                        ELSE s.IsInProgress
                                     END,
            InProgressClaimedOnUtc = CASE
                                        WHEN @ForceRequeue = 1 THEN NULL
                                        WHEN @ExistingStatusCode IN (N'Pending', N'Failed', N'RetryPending') THEN NULL
                                        WHEN @ExistingIsInProgress = 1 THEN NULL
                                        ELSE s.InProgressClaimedOnUtc
                                     END,
            UpdatedByUserID        = SCore.GetCurrentUserId(),
            UpdatedDateTimeUTC     = @NowUtc
        FROM SFin.SageInboundDocumentStatus AS s
        WHERE s.Guid = @StatusGuid
          AND s.RowStatus NOT IN (0,254);
    END;

    SELECT
        @InvoiceRequestID AS InvoiceRequestID,
        @TransactionID AS TransactionID,
        @JobID AS JobID,
        @CymBuildDocumentGuid AS CymBuildDocumentGuid,
        ISNULL(@ExistingStatusCode, N'Pending') AS PreviousStatusCode,
        CASE
            WHEN @ForceRequeue = 1 THEN CAST(1 AS BIT)
            WHEN ISNULL(@ExistingStatusCode, N'Pending') IN (N'Pending', N'Failed', N'RetryPending') THEN CAST(1 AS BIT)
            WHEN ISNULL(@ExistingIsInProgress, 0) = 1 THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS WasRequeued;
END;
GO
