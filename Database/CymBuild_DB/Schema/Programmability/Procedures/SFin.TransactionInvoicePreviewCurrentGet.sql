SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionInvoicePreviewCurrentGet]')
GO

CREATE PROCEDURE [SFin].[TransactionInvoicePreviewCurrentGet]
(
    @TransactionGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        tip.ID,
        tip.Guid,
        tip.TransactionId,
        tip.InvoiceNumberReserved,
        tip.SharePointDriveId,
        tip.SharePointItemId,
        tip.SharePointWebUrl,
        tip.Filename,
        tip.MimeType,
        tip.FileHash,
        tip.SourceTransactionRowVersion,
        tip.GeneratedByUserId,
        tip.GeneratedDateTimeUtc,
        tip.IsCurrent,
        tip.IsPostedToSage,
        tip.PostedToSageDateTimeUtc
    FROM SFin.TransactionInvoicePreviews AS tip
    JOIN SFin.Transactions AS t
        ON t.ID = tip.TransactionId
    WHERE t.Guid = @TransactionGuid
      AND tip.RowStatus NOT IN (0, 254)
      AND tip.IsCurrent = 1
    ORDER BY tip.ID DESC;
END;
GO