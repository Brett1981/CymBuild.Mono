SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionInvoicePreviewPostingGuardGet]')
GO

CREATE PROCEDURE [SFin].[TransactionInvoicePreviewPostingGuardGet]
(
    @TransactionGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        t.ID AS TransactionId,
        t.Guid AS TransactionGuid,
        t.ReservedInvoiceNumber,
        t.RowVersion AS CurrentTransactionRowVersion,
        tip.ID AS PreviewId,
        tip.SourceTransactionRowVersion,
        tip.IsCurrent,
        tip.IsPostedToSage,
        CASE WHEN tip.ID IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS HasPreview,
        CASE WHEN ISNULL(t.ReservedInvoiceNumber, N'') <> N'' THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS HasReservedInvoiceNumber,
        CASE WHEN tip.SourceTransactionRowVersion = t.RowVersion THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS PreviewMatchesCurrentTransaction
    FROM SFin.Transactions AS t
    OUTER APPLY
    (
        SELECT TOP (1) *
        FROM SFin.TransactionInvoicePreviews AS p
        WHERE p.TransactionId = t.ID
          AND p.RowStatus NOT IN (0, 254)
          AND p.IsCurrent = 1
        ORDER BY p.ID DESC
    ) AS tip
    WHERE t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254);
END;
GO