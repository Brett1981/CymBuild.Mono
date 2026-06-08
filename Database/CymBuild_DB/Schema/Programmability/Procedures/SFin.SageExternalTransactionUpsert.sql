SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageExternalTransactionUpsert]')
GO

    CREATE PROCEDURE [SFin].[SageExternalTransactionUpsert]
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
        @AllocatedValue           DECIMAL(18,2) = 0,
        @DocumentDiscountedValue  DECIMAL(18,2) = 0,
        @IsPaid                   BIT = 0,
        @IsFullyPaid              BIT = 0,
        @PaymentStateCode         NVARCHAR(30) = N'Unknown',
        @MatchedTransactionID     BIGINT = -1,
        @MatchedInvoiceRequestID  INT = -1,
        @MatchedJobID             INT = -1,
        @SourceHash               NVARCHAR(128),
        @RawPayloadJson           NVARCHAR(MAX) = NULL,
        @ID                       BIGINT OUTPUT
    )
    AS
    BEGIN
        SET NOCOUNT ON;
        SET XACT_ABORT ON;

        DECLARE
            @NowUtc DATETIME2(7) = GETUTCDATE(),
            @Guid UNIQUEIDENTIFIER;

        SELECT
            @ID = ext.ID,
            @Guid = ext.Guid
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.SageDataset = @SageDataset
          AND ext.SageAccountReference = @SageAccountReference
          AND ext.SageDocumentNo = @SageDocumentNo
          AND ext.SageTransactionReference = @SageTransactionReference
          AND ext.RowStatus NOT IN (0,254);

        IF ISNULL(@ID, -1) > 0
        BEGIN
            UPDATE SFin.SageExternalTransactions
            SET
                SecondReference         = @SecondReference,
                SageTransactionTypeCode = @SageTransactionTypeCode,
                TransactionDate         = @TransactionDate,
                NetAmount               = @NetAmount,
                TaxAmount               = @TaxAmount,
                GrossAmount             = @GrossAmount,
                OutstandingAmount       = @OutstandingAmount,
                AllocatedValue          = @AllocatedValue,
                DocumentDiscountedValue = @DocumentDiscountedValue,
                IsPaid                  = @IsPaid,
                IsFullyPaid             = @IsFullyPaid,
                PaymentStateCode        = @PaymentStateCode,
                MatchedTransactionID    = @MatchedTransactionID,
                MatchedInvoiceRequestID = @MatchedInvoiceRequestID,
                MatchedJobID            = @MatchedJobID,
                SourceHash              = @SourceHash,
                LastSeenOnUtc           = @NowUtc,
                RawPayloadJson          = @RawPayloadJson,
                UpdatedByUserID         = SCore.GetCurrentUserId(),
                UpdatedDateTimeUTC      = @NowUtc
            WHERE ID = @ID
              AND RowStatus NOT IN (0,254);

            RETURN;
        END;

        SET @Guid = NEWID();

        INSERT INTO SCore.DataObjects
        (
            RowStatus,
            Guid,
            EntityTypeID
        )
        SELECT
            1,
            @Guid,
            et.ID
        FROM SCore.EntityTypes AS et
        WHERE et.RowStatus NOT IN (0,254)
          AND et.Name = N'Sage External Transactions';

        /*
            Fallback: if the entity type is not present, do not fail deployment here.
            We preserve current behaviour by only inserting the DataObject row when
            the metadata entity exists.
        */

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
            AllocatedValue,
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
            @OutstandingAmount,
            @AllocatedValue,
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

        SET @ID = SCOPE_IDENTITY();
    END;
    
GO