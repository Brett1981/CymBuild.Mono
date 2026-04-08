CREATE OR ALTER PROCEDURE [SFin].[InvoiceRequestPaymentStatus_ApplyFromSage]
(
    @InvoiceRequestID INT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @PaidStatusID      INT = -1,
        @PartPaidStatusID  INT = -1,
        @ExternalInvoiceID BIGINT = -1,
        @GrossAmount       DECIMAL(18,2) = 0,
        @OutstandingAmount DECIMAL(18,2) = 0,
        @TargetStatusID    INT = -1;

    /*
        Resolve payment statuses by name.
        Adjust names here if your seed data uses different labels.
    */
    SELECT TOP (1) @PaidStatusID = ips.ID
    FROM SFin.InvoicePaymentStatus ips
    WHERE ips.RowStatus NOT IN (0,254)
      AND ips.Name = N'Paid'
    ORDER BY ips.ID;

    SELECT TOP (1) @PartPaidStatusID = ips.ID
    FROM SFin.InvoicePaymentStatus ips
    WHERE ips.RowStatus NOT IN (0,254)
      AND ips.Name = N'Part Paid'
    ORDER BY ips.ID;

    IF @PaidStatusID <= 0
        RAISERROR('InvoicePaymentStatus row "Paid" was not found.', 16, 1);

    IF @PartPaidStatusID <= 0
        RAISERROR('InvoicePaymentStatus row "Part Paid" was not found.', 16, 1);

    SELECT TOP (1)
        @ExternalInvoiceID = ext.ID,
        @GrossAmount       = ext.GrossAmount,
        @OutstandingAmount = ext.OutstandingAmount
    FROM SFin.SageExternalTransactions ext
    WHERE ext.MatchedInvoiceRequestID = @InvoiceRequestID
      AND ext.SageTransactionTypeCode = 4
      AND ext.RowStatus NOT IN (0,254)
    ORDER BY ext.LastSeenOnUtc DESC, ext.ID DESC;

    IF @ExternalInvoiceID <= 0
    BEGIN
        RETURN;
    END;

    SET @TargetStatusID =
        CASE
            WHEN @OutstandingAmount <= 0
                THEN @PaidStatusID
            WHEN @OutstandingAmount > 0
             AND @OutstandingAmount < @GrossAmount
                THEN @PartPaidStatusID
            ELSE -1
        END;

    /*
        Leave current unpaid/open state alone when outstanding >= gross.
        This procedure only projects Paid / Part Paid.
    */
    IF @TargetStatusID > 0
    BEGIN
        UPDATE ir
        SET
            InvoicePaymentStatusID = @TargetStatusID
        FROM SFin.InvoiceRequests ir
        WHERE ir.ID = @InvoiceRequestID
          AND ir.RowStatus NOT IN (0,254);
    END;
END;
GO