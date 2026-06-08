SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceRequestPaymentStatus_ApplyFromSage]')
GO

CREATE PROCEDURE [SFin].[InvoiceRequestPaymentStatus_ApplyFromSage]
(
    @InvoiceRequestID INT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @PaidStatusID      INT = -1,
        @PendingStatusID   INT = -1,
        @ExternalInvoiceID BIGINT = -1,
        @PaymentStateCode  NVARCHAR(30) = N'',
        @GrossAmount       DECIMAL(18,2) = 0,
        @OutstandingAmount DECIMAL(18,2) = 0,
        @TargetStatusID    INT = -1;

    /*
        Resolve supported invoice payment statuses.
        Current InvoicePaymentStatus seed data supports:
        - Paid
        - Pending
        - Overdue
    */
    SELECT TOP (1) @PaidStatusID = ips.ID
    FROM SFin.InvoicePaymentStatus AS ips
    WHERE ips.RowStatus NOT IN (0,254)
      AND ips.Name = N'Paid'
    ORDER BY ips.ID;

    SELECT TOP (1) @PendingStatusID = ips.ID
    FROM SFin.InvoicePaymentStatus AS ips
    WHERE ips.RowStatus NOT IN (0,254)
      AND ips.Name = N'Pending'
    ORDER BY ips.ID;

    IF @PaidStatusID <= 0
    BEGIN
        RAISERROR('InvoicePaymentStatus row "Paid" was not found.', 16, 1);
        RETURN;
    END;

    IF @PendingStatusID <= 0
    BEGIN
        RAISERROR('InvoicePaymentStatus row "Pending" was not found.', 16, 1);
        RETURN;
    END;

    SELECT TOP (1)
        @ExternalInvoiceID = ext.ID,
        @PaymentStateCode  = ISNULL(ext.PaymentStateCode, N''),
        @GrossAmount       = ISNULL(ext.GrossAmount, 0),
        @OutstandingAmount = ISNULL(ext.OutstandingAmount, 0)
    FROM SFin.SageExternalTransactions AS ext
    WHERE ext.MatchedInvoiceRequestID = @InvoiceRequestID
      AND ext.SageTransactionTypeCode = 4
      AND ext.RowStatus NOT IN (0,254)
    ORDER BY ext.LastSeenOnUtc DESC, ext.ID DESC;

    IF @ExternalInvoiceID <= 0
    BEGIN
        RETURN;
    END;

    /*
        Map external Sage aggregate states to supported CymBuild invoice
        payment statuses.

        External states:
        - Paid
        - OverAllocated
        - PartiallyPaid
        - Unpaid
        - Unknown

        Internal InvoicePaymentStatus values:
        - Paid
        - Pending
        - Overdue

        Overdue remains a separate business/time-based concern and is not
        set by this procedure.
    */
    SET @TargetStatusID =
        CASE
            WHEN @PaymentStateCode IN (N'Paid', N'OverAllocated')
                 OR @OutstandingAmount <= 0
                THEN @PaidStatusID

            WHEN @PaymentStateCode IN (N'PartiallyPaid', N'Unpaid', N'Unknown')
                THEN @PendingStatusID

            WHEN @OutstandingAmount > 0
                THEN @PendingStatusID

            ELSE @PendingStatusID
        END;

    UPDATE ir
    SET
        InvoicePaymentStatusID = @TargetStatusID
    FROM SFin.InvoiceRequests AS ir
    WHERE ir.ID = @InvoiceRequestID
      AND ir.RowStatus NOT IN (0,254);
END;
GO