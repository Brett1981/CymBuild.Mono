SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter procedure [SFin].[SageInbound_ReconcileInvoiceTransaction]')
GO
CREATE OR ALTER PROCEDURE [SFin].[SageInbound_ReconcileInvoiceTransaction]
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
        @SageTransactionTypeCode INT,
        @SageTransactionReference NVARCHAR(100),
        @SecondReference NVARCHAR(100),
        @MatchedTransactionID BIGINT = -1,
        @MatchedTransactionGuid UNIQUEIDENTIFIER = NULL,
        @MatchedInvoiceRequestID INT = -1,
        @MatchedJobID INT = -1,
        @MatchRule NVARCHAR(100) = N'NoMatch',
        @IsMatched BIT = 0;

    SELECT
        @SageDataset = ext.SageDataset,
        @SageAccountReference = ext.SageAccountReference,
        @SageDocumentNo = ext.SageDocumentNo,
        @SageTransactionTypeCode = ext.SageTransactionTypeCode,
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

    /*
        Supported customer transaction types are Invoice (4), Credit Note (5)
        and Receipt (1). Credit Notes and Receipts are reconciled to the posted
        Invoice so their allocations can be materialised in CymBuild. Unknown
        transaction types must not be guessed or attached to an Invoice.
    */
    IF ISNULL(@SageTransactionTypeCode, -1) NOT IN (1, 4, 5)
    BEGIN
        UPDATE ext
        SET
            MatchedTransactionID = -1,
            MatchedInvoiceRequestID = -1,
            MatchedJobID = -1,
            UpdatedByUserID = SCore.GetCurrentUserId(),
            UpdatedDateTimeUTC = @NowUtc
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.ID = @ExternalTransactionID
          AND ext.RowStatus NOT IN (0,254);

        SELECT
            ExternalTransactionID = @ExternalTransactionID,
            IsMatched = CAST(0 AS BIT),
            MatchedTransactionID = CAST(-1 AS BIGINT),
            MatchedTransactionGuid = CAST(NULL AS UNIQUEIDENTIFIER),
            MatchedInvoiceRequestID = CAST(-1 AS INT),
            MatchedJobID = CAST(-1 AS INT),
            MatchRule = N'UnsupportedSageTransactionType';

        RETURN;
    END;

    /* 1. Preferred current match */
    SELECT TOP (1)
        @MatchedTransactionID = t.ID,
        @MatchedTransactionGuid = t.Guid,
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
            @MatchedTransactionGuid = t.Guid,
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

        IF ISNULL(@MatchedJobID, -1) <= 0 OR @MatchedTransactionGuid IS NULL
        BEGIN
            SELECT TOP (1)
                @MatchedJobID = CASE WHEN ISNULL(@MatchedJobID, -1) <= 0 THEN ISNULL(t.JobID, -1) ELSE @MatchedJobID END,
                @MatchedTransactionGuid = ISNULL(@MatchedTransactionGuid, t.Guid)
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
        MatchedTransactionGuid = CASE WHEN @IsMatched = 1 THEN @MatchedTransactionGuid ELSE NULL END,
        MatchedInvoiceRequestID = CASE WHEN @IsMatched = 1 THEN ISNULL(@MatchedInvoiceRequestID, -1) ELSE -1 END,
        MatchedJobID = CASE WHEN @IsMatched = 1 THEN ISNULL(@MatchedJobID, -1) ELSE -1 END,
        MatchRule = @MatchRule;
END;
GO
