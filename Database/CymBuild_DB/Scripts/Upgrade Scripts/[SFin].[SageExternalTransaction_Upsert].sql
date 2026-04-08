CREATE OR ALTER PROCEDURE [SFin].[SageExternalTransaction_Upsert]
(
    @SageDataset              NVARCHAR(30),
    @SageAccountReference     NVARCHAR(100),
    @SageDocumentNo           NVARCHAR(100),
    @SageTransactionReference NVARCHAR(100),
    @SecondReference          NVARCHAR(100),
    @SageTransactionTypeCode  INT,
    @TransactionDate          DATE = NULL,
    @NetAmount                DECIMAL(18,2),
    @TaxAmount                DECIMAL(18,2),
    @GrossAmount              DECIMAL(18,2),
    @OutstandingAmount        DECIMAL(18,2),
    @MatchedTransactionID     BIGINT = -1,
    @MatchedInvoiceRequestID  INT = -1,
    @MatchedJobID             INT = -1,
    @SourceHash               NVARCHAR(128),
    @RawPayloadJson           NVARCHAR(MAX) = NULL,
    @Guid                     UNIQUEIDENTIFIER OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2(7) = GETUTCDATE();

    IF EXISTS
    (
        SELECT 1
        FROM SFin.SageExternalTransactions ext
        WHERE ext.SageDataset              = @SageDataset
          AND ext.SageAccountReference     = @SageAccountReference
          AND ext.SageTransactionTypeCode  = @SageTransactionTypeCode
          AND ext.SageDocumentNo           = @SageDocumentNo
          AND ext.SageTransactionReference = @SageTransactionReference
          AND ext.RowStatus NOT IN (0,254)
    )
    BEGIN
        SELECT
            @Guid = ext.Guid
        FROM SFin.SageExternalTransactions ext
        WHERE ext.SageDataset              = @SageDataset
          AND ext.SageAccountReference     = @SageAccountReference
          AND ext.SageTransactionTypeCode  = @SageTransactionTypeCode
          AND ext.SageDocumentNo           = @SageDocumentNo
          AND ext.SageTransactionReference = @SageTransactionReference
          AND ext.RowStatus NOT IN (0,254);

        UPDATE ext
        SET
            SecondReference         = @SecondReference,
            TransactionDate         = @TransactionDate,
            NetAmount               = @NetAmount,
            TaxAmount               = @TaxAmount,
            GrossAmount             = @GrossAmount,
            OutstandingAmount       = @OutstandingAmount,
            MatchedTransactionID    = @MatchedTransactionID,
            MatchedInvoiceRequestID = @MatchedInvoiceRequestID,
            MatchedJobID            = @MatchedJobID,
            SourceHash              = @SourceHash,
            LastSeenOnUtc           = @NowUtc,
            RawPayloadJson          = @RawPayloadJson,
            UpdatedByUserID         = SCore.GetCurrentUserId(),
            UpdatedDateTimeUTC      = @NowUtc
        FROM SFin.SageExternalTransactions ext
        WHERE ext.Guid = @Guid;

        RETURN;
    END;

    IF (@Guid IS NULL OR @Guid = '00000000-0000-0000-0000-000000000000')
    BEGIN
        SET @Guid = NEWID();
    END;

    DECLARE @IsInsert BIT;

    EXEC SCore.UpsertDataObject
         @Guid       = @Guid,
         @SchemeName = N'SFin',
         @ObjectName = N'SageExternalTransactions',
         @IsInsert   = @IsInsert OUTPUT;

    INSERT INTO SFin.SageExternalTransactions
    (
        RowStatus,
        Guid,
        SageDataset,
        SageAccountReference,
        SageDocumentNo,
        SageTransactionReference,
        SecondReference,
        SageTransactionTypeCode,
        TransactionDate,
        NetAmount,
        TaxAmount,
        GrossAmount,
        OutstandingAmount,
        MatchedTransactionID,
        MatchedInvoiceRequestID,
        MatchedJobID,
        SourceHash,
        LastSeenOnUtc,
        RawPayloadJson,
        CreatedByUserID,
        CreatedDateTimeUTC,
        UpdatedByUserID,
        UpdatedDateTimeUTC
    )
    VALUES
    (
        1,
        @Guid,
        @SageDataset,
        @SageAccountReference,
        @SageDocumentNo,
        @SageTransactionReference,
        @SecondReference,
        @SageTransactionTypeCode,
        @TransactionDate,
        @NetAmount,
        @TaxAmount,
        @GrossAmount,
        @OutstandingAmount,
        @MatchedTransactionID,
        @MatchedInvoiceRequestID,
        @MatchedJobID,
        @SourceHash,
        @NowUtc,
        @RawPayloadJson,
        SCore.GetCurrentUserId(),
        @NowUtc,
        SCore.GetCurrentUserId(),
        @NowUtc
    );
END;
GO