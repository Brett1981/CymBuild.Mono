SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageInbound_ApplyAggregatePaymentState]')
GO

CREATE PROCEDURE [SFin].[SageInbound_ApplyAggregatePaymentState]
(
    @ExternalTransactionID BIGINT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @AllocatedValue            DECIMAL(18,2),
        @OutstandingAmount         DECIMAL(18,2),
        @GrossAmount               DECIMAL(18,2),
        @DocumentDiscountedValue   DECIMAL(18,2),
        @IsPaid                    BIT,
        @IsFullyPaid               BIT,
        @PaymentStateCode          NVARCHAR(30),
        @MatchedInvoiceRequestID   INT,
        @NowUtc                    DATETIME2(7) = GETUTCDATE();

    SELECT
        @AllocatedValue          = ext.AllocatedValue,
        @OutstandingAmount       = ext.OutstandingAmount,
        @GrossAmount             = ext.GrossAmount,
        @DocumentDiscountedValue = ext.DocumentDiscountedValue,
        @IsPaid                  = ext.IsPaid,
        @IsFullyPaid             = ext.IsFullyPaid,
        @MatchedInvoiceRequestID = ext.MatchedInvoiceRequestID
    FROM SFin.SageExternalTransactions AS ext
    WHERE ext.ID = @ExternalTransactionID
      AND ext.RowStatus NOT IN (0,254);

    IF @AllocatedValue IS NULL
    BEGIN
        RAISERROR('Sage external transaction not found.', 16, 1);
        RETURN;
    END;

    SET @PaymentStateCode =
        CASE
            WHEN ISNULL(@AllocatedValue, 0) > ISNULL(@GrossAmount, 0)
                 AND ISNULL(@GrossAmount, 0) > 0
                THEN N'OverAllocated'
            WHEN ISNULL(@IsFullyPaid, 0) = 1
                 OR ISNULL(@OutstandingAmount, 0) <= 0
                THEN N'Paid'
            WHEN ISNULL(@AllocatedValue, 0) > 0
                 AND ISNULL(@OutstandingAmount, 0) > 0
                THEN N'PartiallyPaid'
            WHEN ISNULL(@AllocatedValue, 0) = 0
                 AND ISNULL(@OutstandingAmount, 0) > 0
                THEN N'Unpaid'
            ELSE N'Unknown'
        END;

    UPDATE SFin.SageExternalTransactions
    SET
        PaymentStateCode   = @PaymentStateCode,
        UpdatedByUserID    = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC = @NowUtc
    WHERE ID = @ExternalTransactionID
      AND RowStatus NOT IN (0,254);

    IF ISNULL(@MatchedInvoiceRequestID, -1) > 0
       AND OBJECT_ID(N'SFin.InvoiceRequestPaymentStatus_ApplyFromSage', N'P') IS NOT NULL
    BEGIN
        EXEC SFin.InvoiceRequestPaymentStatus_ApplyFromSage
            @InvoiceRequestID = @MatchedInvoiceRequestID;
    END;

    SELECT
        ExternalTransactionID   = @ExternalTransactionID,
        PaymentStateCode        = @PaymentStateCode,
        AllocatedValue          = @AllocatedValue,
        OutstandingAmount       = @OutstandingAmount,
        GrossAmount             = @GrossAmount,
        DocumentDiscountedValue = @DocumentDiscountedValue,
        IsPaid                  = ISNULL(@IsPaid, 0),
        IsFullyPaid             = ISNULL(@IsFullyPaid, 0);
END;
GO