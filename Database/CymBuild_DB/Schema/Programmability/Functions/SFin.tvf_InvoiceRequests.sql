SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create function [SFin].[tvf_InvoiceRequests]')
GO
CREATE FUNCTION [SFin].[tvf_InvoiceRequests]
(
    @UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
SELECT
    ir.ID,
    ir.RowStatus,
    ir.RowVersion,
    ir.Guid,
    ir.Notes,
    ir.CreatedDateTimeUTC,
    ir.InvoicingType,
    ir.ExpectedDate,
    ir.ManualStatus,
    i.Guid AS RequesterUserId,
    i.FullName AS SurveyorName,
    j.Guid AS JobId,
    j.Number,
    j.FinanceAccountID,
    FinAcc.Name AS FinanceAccountName,
    FinAcc.Code AS FinanceAccountCode,
    STRING_AGG(ActT.Name, ', ') AS ActivityID,
    Acc.Name AS ClientName,
    SUM(IRI.Net) AS Net,
    MAX(Act.EndDate) AS EndDate,
    j.BillingInstruction AS JobBillingInstruction,
    FinAcc.BillingInstruction AS CRMBillingInstruction,
    CASE
        WHEN MAX
        (
            CASE
                WHEN ActT.IsBillable = 0 THEN 'No'
                ELSE 'Yes'
            END
        ) = 'Yes' THEN 'Yes'
        ELSE 'No'
    END AS IsBillable,
    OrgUnit.Name AS OrgUnit,
    CAST
    (
        CASE
            WHEN j.FinanceAccountID IS NULL OR j.FinanceAccountID <= 0 THEN 1
            WHEN NULLIF(LTRIM(RTRIM(FinAcc.Code)), N'') IS NULL THEN 1
            ELSE 0
        END
        AS bit
    ) AS HasFinanceAccountIssue,
    CASE
        WHEN j.FinanceAccountID IS NULL OR j.FinanceAccountID <= 0
            THEN N'No finance account selected.'
        WHEN NULLIF(LTRIM(RTRIM(FinAcc.Code)), N'') IS NULL
            THEN N'Finance account does not have a valid Sage Code.'
        ELSE N''
    END AS FinanceAccountIssueMessage,
    CAST
    (
        CASE
            WHEN SUM(IRI.Net) <= 0 THEN 1
            ELSE 0
        END
        AS bit
    ) AS HasBatchingIssue,
    CASE
        WHEN SUM(IRI.Net) <= 0
            THEN N'Invoice request value is zero or negative and cannot be converted into a transaction.'
        ELSE N''
    END AS BatchingIssueMessage
FROM SFin.InvoiceRequests AS ir
JOIN SJob.Jobs AS j
    ON j.ID = ir.JobId
JOIN SCore.Identities AS i
    ON i.ID = ir.RequesterUserId
JOIN SCore.OrganisationalUnits AS OrgUnit
    ON OrgUnit.ID = j.OrganisationalUnitID
INNER JOIN SFin.InvoiceRequestItems AS IRI
    ON IRI.InvoiceRequestId = ir.ID
INNER JOIN SJob.Activities AS Act
    ON IRI.ActivityId = Act.ID
INNER JOIN SJob.ActivityTypes AS ActT
    ON Act.ActivityTypeID = ActT.ID
INNER JOIN SCrm.Accounts AS Acc
    ON Acc.ID = j.ClientAccountID
LEFT JOIN SCrm.Accounts AS FinAcc
    ON FinAcc.ID = j.FinanceAccountID
WHERE
    ir.RowStatus NOT IN (0, 254)
    AND ir.ID > 0
    AND j.CannotBeInvoiced <> 1
    AND ir.IsMerged = 0
    AND EXISTS
    (
        SELECT 1
        FROM SFin.InvoiceRequestItems AS iri
        WHERE iri.RowStatus NOT IN (0, 254)
          AND iri.InvoiceRequestId = ir.ID
    )
    AND
    (
        EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceRequestItems AS iri
            INNER JOIN SJob.Activities AS act
                ON iri.ActivityId = act.ID
            WHERE (act.ActivityStatusID = 3 OR act.ID < 0)
              AND iri.InvoiceRequestId = ir.ID
              AND iri.RowStatus NOT IN (0, 254)
              AND act.RowStatus NOT IN (0, 254)
        )
        OR IRI.ActivityId < 0
    )
    AND
    (
        EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceRequestItems AS iri
            INNER JOIN SJob.Activities AS Act
                ON iri.ActivityId = Act.ID
            WHERE iri.RowStatus NOT IN (0, 254)
              AND Act.RowStatus NOT IN (0, 254)
              AND CAST(Act.EndDate AS date) <= CAST(GETDATE() AS date)
              AND iri.InvoiceRequestId = ir.ID
        )
        OR IRI.ActivityId < 0
    )
    AND EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
    )
    AND EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(ir.Guid, @UserId) AS oscr
    )
    AND NOT EXISTS
    (
        SELECT 1
        FROM SFin.TransactionDetails AS td
        INNER JOIN SFin.InvoiceRequestItems AS iri
            ON iri.ID = td.InvoiceRequestItemId
        WHERE iri.InvoiceRequestId = ir.ID
          AND td.RowStatus NOT IN (0, 254)
          AND iri.RowStatus NOT IN (0, 254)
    )
GROUP BY
    ir.ID,
    ir.RowStatus,
    ir.RowVersion,
    ir.Guid,
    ir.Notes,
    ir.CreatedDateTimeUTC,
    ir.InvoicingType,
    ir.ExpectedDate,
    ir.ManualStatus,
    i.Guid,
    i.FullName,
    j.Guid,
    j.Number,
    j.FinanceAccountID,
    FinAcc.Name,
    FinAcc.Code,
    Acc.Name,
    j.BillingInstruction,
    FinAcc.BillingInstruction,
    OrgUnit.Name;
GO