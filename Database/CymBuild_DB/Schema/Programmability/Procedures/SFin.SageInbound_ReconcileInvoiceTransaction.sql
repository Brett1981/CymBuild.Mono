SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageInbound_ReconcileInvoiceTransaction]')
GO
CREATE PROCEDURE [SFin].[SageInbound_ReconcileInvoiceTransaction]
(
    @ExternalTransactionID BIGINT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @NowUtc DATETIME2(7) = SYSUTCDATETIME(),
        @SageDataset NVARCHAR(30),
        @SageAccountReference NVARCHAR(100),
        @SageDocumentNo NVARCHAR(100),
        @SageTransactionReference NVARCHAR(100),
        @SecondReference NVARCHAR(100),
        @MatchedTransactionID BIGINT = -1,
        @MatchedInvoiceRequestID INT = -1,
        @MatchedJobID INT = -1,
        @MatchRule NVARCHAR(100) = N'NoMatch',
        @IsMatched BIT = 0;

    SELECT
        @SageDataset = ext.SageDataset,
        @SageAccountReference = ext.SageAccountReference,
        @SageDocumentNo = ext.SageDocumentNo,
        @SageTransactionReference = ext.SageTransactionReference,
        @SecondReference = ext.SecondReference
    FROM SFin.SageExternalTransactions AS ext
    WHERE ext.ID = @ExternalTransactionID
      AND ext.RowStatus NOT IN (0,254);

    IF @SageDocumentNo IS NULL
    BEGIN
        RAISERROR('Sage external transaction not found.', 16, 1);
        RETURN;
    END;

    /* 1. Preferred current match */
    SELECT TOP (1)
        @MatchedTransactionID = t.ID,
        @MatchedJobID = ISNULL(t.JobID, -1),
        @MatchRule = N'ReservedInvoiceNumber=SageDocumentNo'
    FROM SFin.Transactions AS t
    WHERE t.RowStatus NOT IN (0,254)
      AND ISNULL(t.ReservedInvoiceNumber, N'') = ISNULL(@SageDocumentNo, N'')
    ORDER BY t.ID DESC;

    /* 2. Backward-compatible fallback for already-enqueued inbound rows */
    IF ISNULL(@MatchedTransactionID, -1) <= 0
    BEGIN
        SELECT TOP (1)
            @MatchedTransactionID = s.TransactionID,
            @MatchedInvoiceRequestID = s.InvoiceRequestID,
            @MatchedJobID = s.JobID,
            @MatchRule = N'InboundStatus.TransactionID'
        FROM SFin.SageInboundDocumentStatus AS s
        WHERE s.RowStatus NOT IN (0,254)
          AND s.TransactionID > 0
          AND s.SageDataset = @SageDataset
          AND s.SageAccountReference = @SageAccountReference
          AND s.SageDocumentNo = @SageDocumentNo
        ORDER BY s.ID DESC;
    END;

    /* 3. Secondary ReservedInvoiceNumber fallback */
    IF ISNULL(@MatchedTransactionID, -1) <= 0
       AND ISNULL(@SecondReference, N'') <> N''
    BEGIN
        SELECT TOP (1)
            @MatchedTransactionID = t.ID,
            @MatchedJobID = ISNULL(t.JobID, -1),
            @MatchRule = N'ReservedInvoiceNumber=SecondReference'
        FROM SFin.Transactions AS t
        WHERE t.RowStatus NOT IN (0,254)
          AND ISNULL(t.ReservedInvoiceNumber, N'') = ISNULL(@SecondReference, N'')
        ORDER BY t.ID DESC;
    END;

    IF ISNULL(@MatchedTransactionID, -1) > 0
    BEGIN
        IF ISNULL(@MatchedInvoiceRequestID, -1) <= 0
        BEGIN
            SELECT TOP (1)
                @MatchedInvoiceRequestID = ISNULL(iri.InvoiceRequestID, -1)
            FROM SFin.TransactionDetails AS td
            JOIN SFin.InvoiceRequestItems AS iri
                ON iri.ID = td.InvoiceRequestItemId
               AND iri.RowStatus NOT IN (0,254)
            WHERE td.TransactionID = @MatchedTransactionID
              AND td.RowStatus NOT IN (0,254)
              AND td.InvoiceRequestItemId IS NOT NULL
            ORDER BY td.ID DESC;
        END;

        IF ISNULL(@MatchedJobID, -1) <= 0
        BEGIN
            SELECT TOP (1)
                @MatchedJobID = ISNULL(t.JobID, -1)
            FROM SFin.Transactions AS t
            WHERE t.ID = @MatchedTransactionID
              AND t.RowStatus NOT IN (0,254);
        END;

        SET @IsMatched = 1;
    END;

    UPDATE ext
    SET
        MatchedTransactionID = CASE WHEN @IsMatched = 1 THEN @MatchedTransactionID ELSE -1 END,
        MatchedInvoiceRequestID = CASE WHEN @IsMatched = 1 THEN ISNULL(@MatchedInvoiceRequestID, -1) ELSE -1 END,
        MatchedJobID = CASE WHEN @IsMatched = 1 THEN ISNULL(@MatchedJobID, -1) ELSE -1 END,
        UpdatedByUserID = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC = @NowUtc
    FROM SFin.SageExternalTransactions AS ext
    WHERE ext.ID = @ExternalTransactionID
      AND ext.RowStatus NOT IN (0,254);

    SELECT
        ExternalTransactionID = @ExternalTransactionID,
        IsMatched = @IsMatched,
        MatchedTransactionID = CASE WHEN @IsMatched = 1 THEN @MatchedTransactionID ELSE -1 END,
        MatchedInvoiceRequestID = CASE WHEN @IsMatched = 1 THEN ISNULL(@MatchedInvoiceRequestID, -1) ELSE -1 END,
        MatchedJobID = CASE WHEN @IsMatched = 1 THEN ISNULL(@MatchedJobID, -1) ELSE -1 END,
        MatchRule = @MatchRule;
END;
GO