IF OBJECT_ID(N'SFin.TransactionInvoicePreviewInvalidateCurrent', N'P') IS NOT NULL
    DROP PROCEDURE SFin.TransactionInvoicePreviewInvalidateCurrent;
GO

CREATE PROCEDURE SFin.TransactionInvoicePreviewInvalidateCurrent
(
    @TransactionId BIGINT
)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE SFin.TransactionInvoicePreviews
    SET IsCurrent = 0
    WHERE TransactionId = @TransactionId
      AND RowStatus NOT IN (0, 254)
      AND IsCurrent = 1;
END;
GO