SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create procedure [SFin].[SageInboundDiagnostics_GetSummary]')
GO

/*
    Returns grand-total counts across every record matching the search filters,
    independent of the quick-filter status/payment selection currently applied
    to the main grid. SFin.SageInboundDiagnostics_Get is paged, so the row set
    it returns can no longer be counted client-side to drive the summary cards.
*/
CREATE OR ALTER PROCEDURE [SFin].[SageInboundDiagnostics_GetSummary]
(
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
        TotalCount           = COUNT(1),
        SucceededCount       = ISNULL(SUM(CASE WHEN d.StatusCode = N'Succeeded' THEN 1 ELSE 0 END), 0),
        RetryPendingCount    = ISNULL(SUM(CASE WHEN d.StatusCode = N'RetryPending' THEN 1 ELSE 0 END), 0),
        PaidCount            = ISNULL(SUM(CASE WHEN d.LastPaymentStateCode = N'Paid' THEN 1 ELSE 0 END), 0),
        -- CYB-555: the materialised transaction is a Credit Note when the
        -- matched Sage row is type 5, and a Receipt otherwise.
        ReceiptsCreatedCount = ISNULL(SUM(CASE WHEN d.MaterialisedReceiptTransactionGuid IS NOT NULL
                                                AND ISNULL(d.LastMatchedExternalTransactionTypeCode, -1) <> 5 THEN 1 ELSE 0 END), 0),
        CreditNotesCreatedCount = ISNULL(SUM(CASE WHEN d.MaterialisedReceiptTransactionGuid IS NOT NULL
                                                   AND d.LastMatchedExternalTransactionTypeCode = 5 THEN 1 ELSE 0 END), 0)
    FROM SFin.tvf_SageInboundDiagnostics
    (
        NULL,  -- StatusCode: always ignored here so every card reflects the full matching population
        @SageAccountReference,
        @SageDocumentNo,
        @OnlyRetryableFailures,
        @InvoiceRequestID,
        @TransactionID,
        @JobID,
        @TransactionNumber
    ) AS d;
END
GO
