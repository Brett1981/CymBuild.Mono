IF OBJECT_ID(N'SFin.TransactionReserveInvoiceNumber', N'P') IS NOT NULL
    DROP PROCEDURE SFin.TransactionReserveInvoiceNumber;
GO

CREATE PROCEDURE SFin.TransactionReserveInvoiceNumber
(
    @TransactionGuid UNIQUEIDENTIFIER,
    @ReservedInvoiceNumber NVARCHAR(30) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TransactionId BIGINT;
    DECLARE @CurrentReservedInvoiceNumber NVARCHAR(30);
    DECLARE @TransactionNumber NVARCHAR(30);

    SELECT
        @TransactionId = t.ID,
        @CurrentReservedInvoiceNumber = t.ReservedInvoiceNumber,
        @TransactionNumber = t.Number
    FROM SFin.Transactions AS t
    WHERE t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254);

    IF @TransactionId IS NULL
    BEGIN
        ;THROW 60001, N'Transaction not found.', 1;
    END;

    IF ISNULL(@CurrentReservedInvoiceNumber, N'') <> N''
    BEGIN
        SET @ReservedInvoiceNumber = @CurrentReservedInvoiceNumber;
        RETURN;
    END;

    /*
        Final implementation note:
        This uses the current transaction number as the outbound invoice number unless business rules later require a separate sequence.
        If a separate invoice sequence is later required, replace the next assignment here only.
    */
    SET @ReservedInvoiceNumber = @TransactionNumber;

    UPDATE SFin.Transactions
    SET ReservedInvoiceNumber = @ReservedInvoiceNumber
    WHERE ID = @TransactionId;
END;
GO