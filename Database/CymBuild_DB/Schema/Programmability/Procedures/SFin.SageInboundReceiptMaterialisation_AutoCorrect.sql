SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageInboundReceiptMaterialisation_AutoCorrect]')
GO
CREATE PROCEDURE [SFin].[SageInboundReceiptMaterialisation_AutoCorrect]
(
    @ExternalTransactionID BIGINT = NULL,
    @BatchSize INT = 100,
    @DryRun BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
        @CurrentExternalTransactionID BIGINT,
        @ProcessedCount INT = 0,
        @CorrectedCount INT = 0,
        @SkippedCount INT = 0,
        @FailedCount INT = 0;

    DECLARE @Candidates TABLE
    (
        RowNumber INT IDENTITY(1,1) NOT NULL,
        ExternalTransactionID BIGINT NOT NULL
    );

    DECLARE @Results TABLE
    (
        ExternalTransactionID BIGINT NOT NULL,
        Outcome NVARCHAR(30) NOT NULL,
        Message NVARCHAR(2000) NOT NULL,
        MatchedTransactionID BIGINT NULL,
        MaterialisedReceiptTransactionID BIGINT NULL,
        MaterialisedAllocationID BIGINT NULL
    );

    INSERT INTO @Candidates
    (
        ExternalTransactionID
    )
    SELECT TOP (@BatchSize)
        ext.ID
    FROM SFin.SageExternalTransactions AS ext
    WHERE ext.RowStatus NOT IN (0,254)
      AND ISNULL(ext.AllocatedValue, 0) > 0
      AND
      (
            @ExternalTransactionID IS NULL
         OR ext.ID = @ExternalTransactionID
      )
      AND ext.MaterialisedReceiptTransactionID IS NULL
    ORDER BY ext.ID;

    IF @DryRun = 1
    BEGIN
        SELECT
            ProcessedCount = COUNT(1),
            CorrectedCount = 0,
            SkippedCount = COUNT(1),
            FailedCount = 0
        FROM @Candidates;

        SELECT
            c.ExternalTransactionID,
            Outcome = N'DryRun',
            Message = N'Candidate would be reconciled and materialised.',
            MatchedTransactionID = ext.MatchedTransactionID,
            MaterialisedReceiptTransactionID = ext.MaterialisedReceiptTransactionID,
            MaterialisedAllocationID = ext.MaterialisedAllocationID
        FROM @Candidates AS c
        JOIN SFin.SageExternalTransactions AS ext
            ON ext.ID = c.ExternalTransactionID
           AND ext.RowStatus NOT IN (0,254)
        ORDER BY c.ExternalTransactionID;

        RETURN;
    END;

    DECLARE candidate_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        c.ExternalTransactionID
    FROM @Candidates AS c
    ORDER BY c.ExternalTransactionID;

    OPEN candidate_cursor;

    FETCH NEXT FROM candidate_cursor INTO @CurrentExternalTransactionID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            DECLARE @ReconcileResult TABLE
            (
                ExternalTransactionID BIGINT,
                IsMatched BIT,
                MatchedTransactionID BIGINT,
                MatchedInvoiceRequestID INT,
                MatchedJobID INT,
                MatchRule NVARCHAR(100)
            );

            DECLARE @PaymentStateResult TABLE
            (
                ExternalTransactionID BIGINT,
                PaymentStateCode NVARCHAR(30),
                AllocatedValue DECIMAL(18,2),
                OutstandingAmount DECIMAL(18,2),
                GrossAmount DECIMAL(18,2),
                DocumentDiscountedValue DECIMAL(18,2),
                IsPaid BIT,
                IsFullyPaid BIT
            );

            INSERT INTO @ReconcileResult
            (
                ExternalTransactionID,
                IsMatched,
                MatchedTransactionID,
                MatchedInvoiceRequestID,
                MatchedJobID,
                MatchRule
            )
            EXEC SFin.SageInbound_ReconcileInvoiceTransaction
                @ExternalTransactionID = @CurrentExternalTransactionID;

            INSERT INTO @PaymentStateResult
            (
                ExternalTransactionID,
                PaymentStateCode,
                AllocatedValue,
                OutstandingAmount,
                GrossAmount,
                DocumentDiscountedValue,
                IsPaid,
                IsFullyPaid
            )
            EXEC SFin.SageInbound_ApplyAggregatePaymentState
                @ExternalTransactionID = @CurrentExternalTransactionID;

            EXEC SFin.SageInboundReceiptAndAllocation_Materialise
                @ExternalTransactionID = @CurrentExternalTransactionID;

            INSERT INTO @Results
            (
                ExternalTransactionID,
                Outcome,
                Message,
                MatchedTransactionID,
                MaterialisedReceiptTransactionID,
                MaterialisedAllocationID
            )
            SELECT
                ext.ID,
                CASE
                    WHEN ext.MaterialisedReceiptTransactionID IS NOT NULL
                     AND ext.MaterialisedAllocationID IS NOT NULL
                        THEN N'Corrected'
                    WHEN ISNULL(ext.MatchedTransactionID, -1) <= 0
                        THEN N'Skipped'
                    ELSE N'Skipped'
                END,
                CASE
                    WHEN ext.MaterialisedReceiptTransactionID IS NOT NULL
                     AND ext.MaterialisedAllocationID IS NOT NULL
                        THEN N'Receipt and allocation materialised.'
                    WHEN ISNULL(ext.MatchedTransactionID, -1) <= 0
                        THEN N'Could not reconcile external transaction to a CymBuild invoice transaction.'
                    ELSE N'Materialisation did not create a receipt/allocation. Check ReceiptMaterialisationError.'
                END,
                ext.MatchedTransactionID,
                ext.MaterialisedReceiptTransactionID,
                ext.MaterialisedAllocationID
            FROM SFin.SageExternalTransactions AS ext
            WHERE ext.ID = @CurrentExternalTransactionID
              AND ext.RowStatus NOT IN (0,254);
        END TRY
        BEGIN CATCH
            SET @FailedCount += 1;

            UPDATE ext
            SET
                ReceiptMaterialisationError = LEFT(ERROR_MESSAGE(), 2000),
                UpdatedByUserID = SCore.GetCurrentUserId(),
                UpdatedDateTimeUTC = GETUTCDATE()
            FROM SFin.SageExternalTransactions AS ext
            WHERE ext.ID = @CurrentExternalTransactionID
              AND ext.RowStatus NOT IN (0,254);

            INSERT INTO @Results
            (
                ExternalTransactionID,
                Outcome,
                Message,
                MatchedTransactionID,
                MaterialisedReceiptTransactionID,
                MaterialisedAllocationID
            )
            SELECT
                ext.ID,
                N'Failed',
                LEFT(ERROR_MESSAGE(), 2000),
                ext.MatchedTransactionID,
                ext.MaterialisedReceiptTransactionID,
                ext.MaterialisedAllocationID
            FROM SFin.SageExternalTransactions AS ext
            WHERE ext.ID = @CurrentExternalTransactionID
              AND ext.RowStatus NOT IN (0,254);
        END CATCH;

        FETCH NEXT FROM candidate_cursor INTO @CurrentExternalTransactionID;
    END;

    CLOSE candidate_cursor;
    DEALLOCATE candidate_cursor;

    SELECT
        @ProcessedCount = COUNT(1),
        @CorrectedCount = SUM(CASE WHEN Outcome = N'Corrected' THEN 1 ELSE 0 END),
        @SkippedCount = SUM(CASE WHEN Outcome = N'Skipped' THEN 1 ELSE 0 END),
        @FailedCount = SUM(CASE WHEN Outcome = N'Failed' THEN 1 ELSE 0 END)
    FROM @Results;

    SELECT
        ProcessedCount = ISNULL(@ProcessedCount, 0),
        CorrectedCount = ISNULL(@CorrectedCount, 0),
        SkippedCount = ISNULL(@SkippedCount, 0),
        FailedCount = ISNULL(@FailedCount, 0);

    SELECT
        ExternalTransactionID,
        Outcome,
        Message,
        MatchedTransactionID,
        MaterialisedReceiptTransactionID,
        MaterialisedAllocationID
    FROM @Results
    ORDER BY ExternalTransactionID;
END;
GO