SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter procedure [SFin].[SageInbound_ReconcileAllocations]')
GO

/*
    CYB-555: turns one recorded Sage allocation (SFin.SageInbound_RecordAllocation)
    into CymBuild records.

    - The target is the Sage invoice row; MatchedTargetTransactionID is the
      CymBuild invoice it was reconciled to.
    - A Receipt (1) or Credit Note (5) counterpart is materialised by
      SFin.SageInboundReceiptAndAllocation_Materialise in pair mode: one CymBuild
      Receipt/Credit Note per (counterpart, invoice), on the invoice's job, for
      the amount Sage applied to that invoice. MatchedSourceTransactionID is that
      CymBuild transaction.
    - An unresolved counterpart (-1) creates nothing: the invoice is settled,
      method unknown. MatchedSourceTransactionID stays -1. A Receipt is never
      invented.

    Idempotent: re-running updates the same CymBuild transaction and allocation.
*/
CREATE OR ALTER PROCEDURE [SFin].[SageInbound_ReconcileAllocations]
(
    @ExternalAllocationID BIGINT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @SourceExternalTransactionID BIGINT,
        @TargetExternalTransactionID BIGINT,
        @CounterpartTypeCode         INT,
        @InvoiceTransactionID        BIGINT = -1,
        @MatchedSourceTransactionID  BIGINT = -1,
        @MatchedTargetTransactionID  BIGINT = -1;

    SELECT
        @SourceExternalTransactionID = a.SourceExternalTransactionID,
        @TargetExternalTransactionID = a.TargetExternalTransactionID
    FROM SFin.SageExternalAllocations AS a
    WHERE a.ID = @ExternalAllocationID
      AND a.RowStatus NOT IN (0,254);

    IF @SourceExternalTransactionID IS NULL
    BEGIN
        RAISERROR('Sage external allocation not found.', 16, 1);
        RETURN;
    END;

    SELECT @CounterpartTypeCode = src.SageTransactionTypeCode
    FROM SFin.SageExternalTransactions AS src
    WHERE src.ID = @SourceExternalTransactionID
      AND src.RowStatus NOT IN (0,254);

    SELECT @InvoiceTransactionID = ISNULL(tgt.MatchedTransactionID, -1)
    FROM SFin.SageExternalTransactions AS tgt
    WHERE tgt.ID = @TargetExternalTransactionID
      AND tgt.RowStatus NOT IN (0,254);

    UPDATE a
    SET
        MatchedTargetTransactionID = ISNULL(@InvoiceTransactionID, -1),
        UpdatedByUserID            = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC         = GETUTCDATE()
    FROM SFin.SageExternalAllocations AS a
    WHERE a.ID = @ExternalAllocationID;

    -- CYB-555-RECONCILE-PAIR-MODE
    IF @CounterpartTypeCode IN (1, 5)
       AND ISNULL(@InvoiceTransactionID, -1) > 0
    BEGIN
        EXECUTE SFin.SageInboundReceiptAndAllocation_Materialise
             @ExternalTransactionID        = @SourceExternalTransactionID,
             @InvoiceExternalTransactionID = @TargetExternalTransactionID;
    END;

    SELECT
        @MatchedSourceTransactionID = a.MatchedSourceTransactionID,
        @MatchedTargetTransactionID = a.MatchedTargetTransactionID
    FROM SFin.SageExternalAllocations AS a
    WHERE a.ID = @ExternalAllocationID;

    SELECT
        @ExternalAllocationID AS ExternalAllocationID,
        CAST
        (
            CASE
                WHEN ISNULL(@MatchedSourceTransactionID, -1) > 0
                 AND ISNULL(@MatchedTargetTransactionID, -1) > 0
                THEN 1 ELSE 0
            END
            AS BIT
        ) AS IsFullyMatched,
        ISNULL(@MatchedSourceTransactionID, -1) AS MatchedSourceTransactionID,
        ISNULL(@MatchedTargetTransactionID, -1) AS MatchedTargetTransactionID;
END;
GO
