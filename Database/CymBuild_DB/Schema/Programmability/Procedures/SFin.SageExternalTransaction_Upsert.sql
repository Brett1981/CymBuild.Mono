SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageExternalTransaction_Upsert]')
GO
/*
    CYB-555 (v2): the wrapper's v2 endpoints return account codes as Sage holds
    them, with their leading zeros (00030607). Rows stored from v1 hold the
    stripped form (30607). An existing row is found with the zeros ignored on
    both sides, and its account is then updated to the form Sage holds, so an
    invoice first stored from v1 is updated in place rather than duplicated.
*/
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
    @AllocatedValue           DECIMAL(18,2),
    @OutstandingAmount        DECIMAL(18,2),
    @DocumentDiscountedValue  DECIMAL(18,2),
    @IsPaid                   BIT,
    @IsFullyPaid              BIT,
    @PaymentStateCode         NVARCHAR(30),
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

    -- CYB-555-V2-ACCOUNT-ZEROS: compare account codes with their leading zeros stripped.
    DECLARE @StrippedAccountReference NVARCHAR(100) =
        SUBSTRING(@SageAccountReference, PATINDEX(N'%[^0]%', @SageAccountReference + N'.'), 100);

    IF EXISTS
    (
        SELECT 1
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.SageDataset              = @SageDataset
          AND SUBSTRING(ext.SageAccountReference, PATINDEX(N'%[^0]%', ext.SageAccountReference + N'.'), 100) = @StrippedAccountReference
          AND ext.SageTransactionTypeCode  = @SageTransactionTypeCode
          AND ext.SageDocumentNo           = @SageDocumentNo
          AND ext.SageTransactionReference = @SageTransactionReference
          AND ext.RowStatus NOT IN (0,254)
    )
    BEGIN
        SELECT TOP (1)
            @Guid = ext.Guid
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.SageDataset              = @SageDataset
          AND SUBSTRING(ext.SageAccountReference, PATINDEX(N'%[^0]%', ext.SageAccountReference + N'.'), 100) = @StrippedAccountReference
          AND ext.SageTransactionTypeCode  = @SageTransactionTypeCode
          AND ext.SageDocumentNo           = @SageDocumentNo
          AND ext.SageTransactionReference = @SageTransactionReference
          AND ext.RowStatus NOT IN (0,254)
        ORDER BY
            CASE WHEN ext.SageAccountReference = @SageAccountReference THEN 0 ELSE 1 END,
            ext.ID DESC;

        UPDATE ext
        SET
            SageAccountReference     = @SageAccountReference,
            SecondReference          = @SecondReference,
            TransactionDate          = @TransactionDate,
            NetAmount                = @NetAmount,
            TaxAmount                = @TaxAmount,
            GrossAmount              = @GrossAmount,
            AllocatedValue           = @AllocatedValue,
            OutstandingAmount        = @OutstandingAmount,
            DocumentDiscountedValue  = @DocumentDiscountedValue,
            IsPaid                   = @IsPaid,
            IsFullyPaid              = @IsFullyPaid,
            PaymentStateCode         = @PaymentStateCode,
            MatchedTransactionID     = @MatchedTransactionID,
            MatchedInvoiceRequestID  = @MatchedInvoiceRequestID,
            MatchedJobID             = @MatchedJobID,
            SourceHash               = @SourceHash,
            LastSeenOnUtc            = @NowUtc,
            RawPayloadJson           = @RawPayloadJson,
            UpdatedByUserID          = SCore.GetCurrentUserId(),
            UpdatedDateTimeUTC       = @NowUtc
        FROM SFin.SageExternalTransactions AS ext
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
        AllocatedValue,
        OutstandingAmount,
        DocumentDiscountedValue,
        IsPaid,
        IsFullyPaid,
        PaymentStateCode,
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
        @AllocatedValue,
        @OutstandingAmount,
        @DocumentDiscountedValue,
        @IsPaid,
        @IsFullyPaid,
        @PaymentStateCode,
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