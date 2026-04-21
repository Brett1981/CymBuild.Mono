IF OBJECT_ID(N'SFin.Transaction_InvoiceMergeInfo', N'V') IS NOT NULL
    DROP VIEW SFin.Transaction_InvoiceMergeInfo;
GO

CREATE VIEW SFin.Transaction_InvoiceMergeInfo
    --WITH SCHEMABINDING
AS
SELECT
    t.ID,
    t.Guid,
    t.Number AS TransactionNumber,
    t.ReservedInvoiceNumber AS InvoiceNumber,
    t.Date AS InvoiceDate,
    t.PurchaseOrderNumber,
    t.SageTransactionReference,
    t.AccountID,
    acc.Name AS ClientName,
    t.JobID,
    j.Number AS JobNumber,
    j.JobDescription AS JobTitle,
    ct.Name AS CreditTerms,
    cadd.FormattedAddressCR AS ClientAddressBlock,
    ou.Name AS OrganisationalUnitName,
    offadd.Name AS OfficialName,
    offadd.FormattedAddressCR AS OfficialAddressBlock,
    offcon.Email AS OfficialEmail,
    offcon.Phone AS OfficialPhone,
    totals.NetTotal,
    totals.VatTotal,
    totals.GrossTotal,
    totals.StandardVatTotal,
    totals.ZeroVatTotal,
    totals.StandardVatRate
FROM SFin.Transactions AS t
JOIN SCrm.Accounts AS acc
    ON acc.ID = t.AccountID
LEFT JOIN SJob.Jobs AS j
    ON j.ID = t.JobID
LEFT JOIN SFin.CreditTerms AS ct
    ON ct.ID = t.CreditTermsId
LEFT JOIN SCrm.AccountAddresses AS caa
    ON caa.AccountID = acc.ID
   AND caa.IsMain = 1
LEFT JOIN SCrm.Addresses AS cadd
    ON cadd.ID = caa.AddressID
LEFT JOIN SCore.OrganisationalUnits AS ou
    ON ou.ID = t.OrganisationalUnitId
LEFT JOIN SCrm.Addresses AS offadd
    ON offadd.ID = ou.OfficialAddressId
LEFT JOIN SCrm.Contact_MergeInfo AS offcon
    ON offcon.ID = ou.OfficialContactId
OUTER APPLY
(
    SELECT
        SUM(td.Net) AS NetTotal,
        SUM(td.Vat) AS VatTotal,
        SUM(td.Gross) AS GrossTotal,
        SUM(CASE WHEN td.VatRate > 0 THEN td.Vat ELSE 0 END) AS StandardVatTotal,
        SUM(CASE WHEN td.VatRate = 0 THEN td.Net ELSE 0 END) AS ZeroVatTotal,
        MAX(CASE WHEN td.VatRate > 0 THEN td.VatRate END) AS StandardVatRate
    FROM SFin.TransactionDetails AS td
    WHERE td.TransactionID = t.ID
      AND td.RowStatus NOT IN (0, 254)
) AS totals
WHERE t.RowStatus NOT IN (0, 254);
GO