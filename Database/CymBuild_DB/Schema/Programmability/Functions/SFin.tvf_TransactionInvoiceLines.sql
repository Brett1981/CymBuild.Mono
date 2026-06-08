SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[tvf_TransactionInvoiceLines]')
GO

CREATE FUNCTION [SFin].[tvf_TransactionInvoiceLines]
(
    @TransactionGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
(
    SELECT
        td.ID,
        td.Guid,
        t.Guid AS TransactionGuid,
        ROW_NUMBER() OVER (ORDER BY td.ID) AS LineOrder,
        td.Description,
        td.Net,
        td.Vat,
        td.Gross,
        td.VatRate,
        td.InvoiceRequestItemId,
        iri.ShortDescription AS InvoiceRequestItemDescription,
        j.Number AS JobNumber,
        j.JobDescription AS JobTitle
    FROM SFin.Transactions AS t
    JOIN SFin.TransactionDetails AS td
        ON td.TransactionID = t.ID
    LEFT JOIN SFin.InvoiceRequestItems AS iri
        ON iri.ID = td.InvoiceRequestItemId
    LEFT JOIN SJob.Jobs AS j
        ON j.ID = t.JobID
    WHERE t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254)
      AND td.RowStatus NOT IN (0, 254)
);
GO