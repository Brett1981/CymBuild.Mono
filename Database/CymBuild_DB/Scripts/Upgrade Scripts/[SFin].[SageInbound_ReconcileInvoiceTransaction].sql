CREATE OR ALTER PROCEDURE [SFin].[SageInbound_ReconcileInvoiceTransaction]
(
    @ExternalTransactionID BIGINT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @SageTransactionTypeCode  INT,
        @SageAccountReference     NVARCHAR(100),
        @SageDocumentNo           NVARCHAR(100),
        @SageTransactionReference NVARCHAR(100),
        @MatchedTransactionID     BIGINT = -1,
        @MatchedInvoiceRequestID  INT = -1,
        @MatchedJobID             INT = -1;

    SELECT
        @SageTransactionTypeCode  = ext.SageTransactionTypeCode,
        @SageAccountReference     = ext.SageAccountReference,
        @SageDocumentNo           = ext.SageDocumentNo,
        @SageTransactionReference = ext.SageTransactionReference
    FROM SFin.SageExternalTransactions ext
    WHERE ext.ID = @ExternalTransactionID
      AND ext.RowStatus NOT IN (0,254);

    IF @SageTransactionTypeCode IS NULL
    BEGIN
        RAISERROR('Sage external transaction not found.', 16, 1);
        RETURN;
    END;

    /*
        Receipt / credit note rule:
        do not guess direct invoice-request matches here.
        This procedure only deterministically reconciles invoice rows (type 4).
    */
    IF @SageTransactionTypeCode <> 4
    BEGIN
        SELECT
            @ExternalTransactionID AS ExternalTransactionID,
            CAST(0 AS BIT) AS IsMatched,
            CAST(-1 AS BIGINT) AS MatchedTransactionID,
            CAST(-1 AS INT) AS MatchedInvoiceRequestID,
            CAST(-1 AS INT) AS MatchedJobID,
            N'Non-invoice transaction not directly reconciled here.' AS MatchRule;
        RETURN;
    END;

    /* ============================================================
       Rule 1: strongest
       Transactions.SageTransactionReference = ext.SageTransactionReference
    ============================================================ */
    SELECT TOP (1)
        @MatchedTransactionID = t.ID,
        @MatchedJobID         = t.JobID
    FROM SFin.Transactions t
    WHERE t.RowStatus NOT IN (0,254)
      AND t.SageTransactionReference = @SageTransactionReference
    ORDER BY t.ID;

    IF @MatchedTransactionID > 0
    BEGIN
        SELECT TOP (1)
            @MatchedInvoiceRequestID = iri.InvoiceRequestId
        FROM SFin.TransactionDetails td
        JOIN SFin.InvoiceRequestItems iri
            ON iri.ID = td.InvoiceRequestItemId
        WHERE td.TransactionID = @MatchedTransactionID
          AND td.RowStatus NOT IN (0,254)
          AND iri.RowStatus NOT IN (0,254)
        ORDER BY iri.ID;
    END;

    /* ============================================================
       Rule 2:
       Transactions.Number = SageDocumentNo
       and Accounts.Code = SageAccountReference
    ============================================================ */
    IF @MatchedTransactionID <= 0
    BEGIN
        SELECT TOP (1)
            @MatchedTransactionID = t.ID,
            @MatchedJobID         = t.JobID
        FROM SFin.Transactions t
        JOIN SCrm.Accounts a
            ON a.ID = t.AccountID
        WHERE t.RowStatus NOT IN (0,254)
          AND a.RowStatus NOT IN (0,254)
          AND t.Number = @SageDocumentNo
          AND a.Code   = @SageAccountReference
        ORDER BY t.ID;

        IF @MatchedTransactionID > 0
        BEGIN
            SELECT TOP (1)
                @MatchedInvoiceRequestID = iri.InvoiceRequestId
            FROM SFin.TransactionDetails td
            JOIN SFin.InvoiceRequestItems iri
                ON iri.ID = td.InvoiceRequestItemId
            WHERE td.TransactionID = @MatchedTransactionID
              AND td.RowStatus NOT IN (0,254)
              AND iri.RowStatus NOT IN (0,254)
            ORDER BY iri.ID;
        END;
    END;

    /* ============================================================
       Rule 3:
       Bridge through TransactionDetails -> InvoiceRequestItems -> InvoiceRequests
       while keeping account-code / document-number / job consistency.
    ============================================================ */
    IF @MatchedTransactionID <= 0
    BEGIN
        SELECT TOP (1)
            @MatchedTransactionID    = t.ID,
            @MatchedInvoiceRequestID = ir.ID,
            @MatchedJobID            = t.JobID
        FROM SFin.Transactions t
        JOIN SCrm.Accounts a
            ON a.ID = t.AccountID
        JOIN SFin.TransactionDetails td
            ON td.TransactionID = t.ID
        JOIN SFin.InvoiceRequestItems iri
            ON iri.ID = td.InvoiceRequestItemId
        JOIN SFin.InvoiceRequests ir
            ON ir.ID = iri.InvoiceRequestId
        WHERE t.RowStatus NOT IN (0,254)
          AND a.RowStatus NOT IN (0,254)
          AND td.RowStatus NOT IN (0,254)
          AND iri.RowStatus NOT IN (0,254)
          AND ir.RowStatus NOT IN (0,254)
          AND a.Code = @SageAccountReference
          AND (@SageDocumentNo = N'' OR t.Number = @SageDocumentNo)
          AND (ir.JobId = t.JobID OR ir.JobId = -1 OR t.JobID = -1)
        ORDER BY t.ID, ir.ID;
    END;

    UPDATE ext
    SET
        MatchedTransactionID    = @MatchedTransactionID,
        MatchedInvoiceRequestID = @MatchedInvoiceRequestID,
        MatchedJobID            = @MatchedJobID,
        UpdatedByUserID         = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC      = GETUTCDATE()
    FROM SFin.SageExternalTransactions ext
    WHERE ext.ID = @ExternalTransactionID
      AND ext.RowStatus NOT IN (0,254);

    SELECT
        @ExternalTransactionID AS ExternalTransactionID,
        CAST(CASE WHEN @MatchedTransactionID > 0 THEN 1 ELSE 0 END AS BIT) AS IsMatched,
        @MatchedTransactionID AS MatchedTransactionID,
        @MatchedInvoiceRequestID AS MatchedInvoiceRequestID,
        @MatchedJobID AS MatchedJobID,
        CASE
            WHEN @MatchedTransactionID > 0 AND @SageTransactionReference <> N'' THEN N'Rule1_SageReference'
            WHEN @MatchedTransactionID > 0 AND @SageDocumentNo <> N'' THEN N'Rule2_DocumentNo_AccountCode'
            WHEN @MatchedTransactionID > 0 THEN N'Rule3_TransactionDetailBridge'
            ELSE N'Rule4_Unmatched'
        END AS MatchRule;
END;
GO