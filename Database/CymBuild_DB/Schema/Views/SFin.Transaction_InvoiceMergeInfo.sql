SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SFin].[Transaction_InvoiceMergeInfo]')
GO

CREATE VIEW [SFin].[Transaction_InvoiceMergeInfo]
    --WITH SCHEMABINDING
AS
SELECT
    t.ID,
    t.Guid,
    t.Guid AS TransactionGuid,
    t.Number AS TransactionNumber,
    t.ReservedInvoiceNumber AS ReservedInvoiceNumber,
    t.SageInvoiceNumber AS SageInvoiceNumber,
    t.SageSalesOrderNumber AS SageSalesOrderNumber,
    t.Date AS InvoiceDate,
    t.PurchaseOrderNumber,
    t.SageTransactionReference,
    t.AccountID,
    acc.Name AS ClientName,
    t.JobID,
    j.Number AS JobNumber,
    j.ExternalReference AS CustomerReference,
    j.JobDescription AS JobTitle,
    td.Description AS LineDescription,
    CASE
        WHEN t.ExpectedDate IS NULL THEN
            CASE
                WHEN ct.Name IS NULL OR ct.Name = '' THEN '30 Days from date of Invoice'
                ELSE ct.Name
            END
        ELSE 'Invoice is Due ' + CONVERT(VARCHAR(10), t.ExpectedDate, 103)
    END AS CreditTerms,
    cadd.FormattedAddressCR AS ClientAddressBlock,
    fadd.FormattedAddressCR AS InvoiceToBlock,
    ou.Name AS OrganisationalUnitName,
    offadd.Name AS OfficialName,
    offadd.FormattedAddressCR AS OfficialAddressBlock,
    offcon.Email AS OfficialEmail,
    offcon.Phone AS OfficialPhone,
    ISNULL(vc.SageVatNo, N'') AS VatCode,
    ISNULL(td.Qty, 1) AS Quantity,
    LEFT(ou.CostCentreCode, CHARINDEX('-', ou.CostCentreCode + '-') - 1) AS CostCentre,
    SUBSTRING(ou.CostCentreCode, CHARINDEX('-', ou.CostCentreCode + '-') + 1, LEN(ou.CostCentreCode)) AS Department,
    td.Net AS UnitPrice,
    td.Net,
    td.Vat,
    td.Gross,
    totals.NetTotal,
    totals.VatTotal,
    totals.GrossTotal
FROM SFin.Transactions AS t
JOIN SFin.TransactionDetails AS td
    ON td.TransactionID = t.ID
   AND td.RowStatus NOT IN (0, 254)
LEFT JOIN SFin.VatCodes AS vc
    ON vc.ID = td.VatCodeID
   AND vc.RowStatus NOT IN (0, 254)
JOIN SCrm.Accounts AS acc
    ON acc.ID = t.AccountID
LEFT JOIN SJob.Jobs AS j
    ON j.ID = t.JobID
LEFT JOIN SCrm.Accounts AS facc
    ON facc.ID = NULLIF(j.FinanceAccountID, -1)
   AND facc.RowStatus NOT IN (0, 254)

OUTER APPLY
(
    SELECT TOP (1)
        aa.AddressID
    FROM SCrm.AccountAddresses AS aa
    WHERE aa.RowStatus NOT IN (0, 254)
      AND aa.AccountID = COALESCE(NULLIF(j.FinanceAccountID, -1), t.AccountID)
      AND
      (
            aa.ID = NULLIF(j.FinanceAddressID, -1)
         OR aa.ID = NULLIF(facc.MainAccountAddressId, -1)
         OR aa.IsMain = 1
      )
    ORDER BY
        CASE
            WHEN aa.ID = NULLIF(j.FinanceAddressID, -1) THEN 1
            WHEN aa.ID = NULLIF(facc.MainAccountAddressId, -1) THEN 2
            WHEN aa.IsMain = 1 THEN 3
            ELSE 4
        END,
        aa.ID
) AS finaddr

LEFT JOIN SCrm.Addresses AS fadd
    ON fadd.ID = finaddr.AddressID
   AND fadd.RowStatus NOT IN (0, 254)
LEFT JOIN SFin.CreditTerms AS ct
    ON ct.ID = t.CreditTermsId
OUTER APPLY
(
    SELECT TOP (1)
        aa.AddressID
    FROM SCrm.AccountAddresses AS aa
    WHERE aa.RowStatus NOT IN (0, 254)
      AND aa.AccountID = acc.ID
      AND
      (
            aa.ID = NULLIF(acc.MainAccountAddressId, -1)
         OR aa.IsMain = 1
      )
    ORDER BY
        CASE
            WHEN aa.ID = NULLIF(acc.MainAccountAddressId, -1) THEN 1
            WHEN aa.IsMain = 1 THEN 2
            ELSE 3
        END,
        aa.ID
) AS clientaddr

LEFT JOIN SCrm.Addresses AS cadd
    ON cadd.ID = clientaddr.AddressID
   AND cadd.RowStatus NOT IN (0, 254)
LEFT JOIN SCore.OrganisationalUnits AS ou
    ON ou.ID = t.OrganisationalUnitId
LEFT JOIN SCrm.Addresses AS offadd
    ON offadd.ID = ou.OfficialAddressId
LEFT JOIN SCrm.Contact_MergeInfo AS offcon
    ON offcon.ID = ou.OfficialContactId
OUTER APPLY
(
    SELECT
        SUM(td2.Net) AS NetTotal,
        SUM(td2.Vat) AS VatTotal,
        SUM(td2.Gross) AS GrossTotal
    FROM SFin.TransactionDetails AS td2
    WHERE td2.TransactionID = t.ID
      AND td2.RowStatus NOT IN (0, 254)
) AS totals
WHERE t.RowStatus NOT IN (0, 254);
GO