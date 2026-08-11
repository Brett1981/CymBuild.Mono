SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[tvf_AllTransactions]')
GO
PRINT (N'Create function [SFin].[tvf_AllTransactions]')
GO
PRINT (N'Create function [SFin].[tvf_AllTransactions]')
GO

/*
    CYB-445 - Minimal Sage Legacy status correction for All Transactions.

    Authoritative evidence used:
      1. Successful automated Sage submission.
      2. Active membership of a manual/legacy Sage Export.
      3. A non-empty SageTransactionReference.

    Behaviour preserved:
      - Automated Succeeded remains Succeeded.
      - Existing automated non-success statuses remain unchanged where there
        is no manual-export evidence and no Sage reference.
      - Transactions with no automated status and no Sage evidence remain
        Not Sent.
      - Existing columns, calculations, security and overdue logic are retained.

    This deliberately does not infer Sage status from allocation alone.
*/

CREATE FUNCTION [SFin].[tvf_AllTransactions]
(
    @UserId INT
)
RETURNS TABLE
AS
RETURN
SELECT
      t.ID
    , t.RowStatus
    , t.RowVersion
    , t.Guid
    , t.Number
    , t.Date
    , a.Name AS Account
    , tt.Name AS TransactionType
    , tc.Net
    , tc.Vat
    , tc.Gross
    , tc.Outstanding
    , t.SageTransactionReference
    , t.PurchaseOrderNumber
    , i.FullName AS Surveyor
    , t.Batched
    , CASE
          WHEN t.TransactionTypeID = 1
           AND DueDetails.DueDate <= GETUTCDATE()
              THEN N'Overdue'
          ELSE N''
      END AS IsOverdue
    , CASE
          WHEN s.StatusCode = N'Succeeded'
              THEN N'Succeeded'
          WHEN legacy.HasActiveManualSageExport = 1
            OR NULLIF
               (
                   LTRIM
                   (
                       RTRIM
                       (
                           ISNULL(t.SageTransactionReference, N'')
                       )
                   ),
                   N''
               ) IS NOT NULL
              THEN N'Legacy'
          WHEN s.StatusCode IS NULL
              THEN N'Not Sent'
          ELSE s.StatusCode
      END AS SageStatusCode
    , CASE
          WHEN NULLIF
               (
                   LTRIM
                   (
                       RTRIM
                       (
                           ISNULL(t.SageTransactionReference, N'')
                       )
                   ),
                   N''
               ) IS NOT NULL
              THEN 1
          ELSE 0
      END AS HasSageReference
    , OrgUnit.Name AS Department
    , OrgUnit2.Name AS OrgUnit
	,j.Number AS JobNumber,
	j.JobDescription,
	Prods.Products
FROM SFin.Transactions AS t
INNER JOIN SFin.TransactionCalculations AS tc
    ON tc.ID = t.ID
INNER JOIN SFin.TransactionTypes AS tt
    ON tt.ID = t.TransactionTypeID
INNER JOIN SCrm.Accounts AS a
    ON a.ID = t.AccountID
INNER JOIN SCore.Identities AS i
    ON i.ID = t.SurveyorUserId
INNER JOIN SJob.Jobs AS j
    ON j.ID = t.JobID
INNER JOIN SCore.OrganisationalUnits AS OrgUnit
    ON OrgUnit.ID = j.OrganisationalUnitID
INNER JOIN SCore.OrganisationalUnits AS OrgUnit2
    ON OrgUnit.ParentID = OrgUnit2.ID
LEFT JOIN SFin.TransactionSageSubmissionStatus AS s
    ON s.TransactionGuid = t.Guid
   AND s.RowStatus <> 0
   AND s.RowStatus <> 254
CROSS APPLY SFin.tvf_OverdueInvoicesForJob(j.Guid) AS o
OUTER APPLY
(
    SELECT TOP (1)
        CONVERT(BIT, 1) AS HasActiveManualSageExport
    FROM SFin.SageExportTransactions AS setr
    INNER JOIN SFin.SageExports AS se
        ON se.ID = setr.SageExportID
       AND se.RowStatus <> 0
       AND se.RowStatus <> 254
    WHERE setr.TransactionID = t.ID
      AND setr.RowStatus <> 0
      AND setr.RowStatus <> 254
    ORDER BY setr.ID DESC
) AS legacy
OUTER APPLY
	(
		SELECT STRING_AGG(d.Code, ',') AS Products
		FROM
		(
			SELECT DISTINCT p.Code
			FROM SSop.QuoteItems qi
			JOIN SJob.Jobs jobs
				ON jobs.ID = qi.CreatedJobId
			LEFT JOIN SProd.Products p
				ON p.ID = qi.ProductId
			WHERE qi.RowStatus NOT IN (0,254)
			  AND jobs.Guid = j.Guid
		) AS d
	) AS Prods
OUTER APPLY
(
    SELECT
        CASE
            WHEN CAST
                 (
                     SUM(ISNULL(td.Gross, 0))
                     AS DECIMAL(19, 2)
                 ) <> 0
                THEN CAST
                     (
                         COALESCE
                         (
                             CAST(tr.ExpectedDate AS DATE),
                             DATEADD
                             (
                                 DAY,
                                 ISNULL(ct.DueDays, 0),
                                 DATEADD
                                 (
                                     DAY,
                                     30,
                                     ISNULL
                                     (
                                         CAST(t.Date AS DATETIME),
                                         0
                                     )
                                 )
                             )
                         )
                         AS DATE
                     )
            ELSE NULL
        END AS DueDate
    FROM SFin.Transactions AS tr
    INNER JOIN SFin.TransactionTypes AS dueTt
        ON dueTt.ID = tr.TransactionTypeID
    INNER JOIN SJob.Jobs AS dueJob
        ON dueJob.ID = t.JobID
    LEFT JOIN SFin.TransactionDetails AS td
        ON td.TransactionID = t.ID
       AND td.RowStatus <> 0
       AND td.RowStatus <> 254
    LEFT JOIN SFin.CreditTerms AS ct
        ON ct.ID = t.CreditTermsId
       AND ct.RowStatus <> 0
       AND ct.RowStatus <> 254
    WHERE dueJob.ID = t.JobID
      AND tr.ID = t.ID
      AND tr.RowStatus <> 0
      AND tr.RowStatus <> 254
    GROUP BY
          tr.ExpectedDate
        , ct.DueDays
) AS DueDetails
WHERE t.RowStatus <> 0
  AND t.RowStatus <> 254
  AND t.ID > 0
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead
      (
          t.Guid,
          @UserId
      ) AS oscr
  )
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead
      (
          a.Guid,
          @UserId
      ) AS oscr
  )


UNION ALL


SELECT 
		root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.InvoiceNumber,
		root_hobt.InvoiceDate,
		a.Name AS Account,
		N'Subcontractor Invoice' AS TransactionType,
		root_hobt.ValueWithoutVAT AS Net,
		root_hobt.ValueWithVAT AS Vat,
		root_hobt.ValueWithVAT AS Gross,
		0 AS Outstanding,
		N'' AS SageTransactionReference,
		N'' AS PurchaseOrderNumber,
		Surveyor.FullName AS Surveyor,
		0 AS Batched,
		N'' AS IsOverdue,
		N'' AS SageStatusCode,
		N'' AS HasSageReference,
		OrgUnit.Name AS Department,
		OrgUnit2.Name AS OrgUnit,
		j.Number,
		j.JobDescription,
		Prods.Products
FROM SJob.SubContractorInvoices root_hobt
JOIN SJob.Jobs j ON (root_hobt.JobId = j.ID)
JOIN SCore.Identities Surveyor ON (j.SurveyorID = Surveyor.ID)
JOIN SCore.OrganisationalUnits AS OrgUnit
    ON OrgUnit.ID = j.OrganisationalUnitID
JOIN SCore.OrganisationalUnits AS OrgUnit2
	ON OrgUnit.ParentID = OrgUnit2.ID
JOIN SCrm.Accounts AS a  ON (a.ID = root_hobt.SubContractorId)
OUTER APPLY
	(
		SELECT STRING_AGG(d.Code, ',') AS Products
		FROM
		(
			SELECT DISTINCT p.Code
			FROM SSop.QuoteItems qi
			JOIN SJob.Jobs jobs
				ON jobs.ID = qi.CreatedJobId
			LEFT JOIN SProd.Products p
				ON p.ID = qi.ProductId
			WHERE qi.RowStatus NOT IN (0,254)
			  AND jobs.Guid = j.Guid
		) AS d
	) AS Prods
WHERE 
		(root_hobt.RowStatus NOT IN (0,254))
	AND (root_hobt.ID > 0)
	AND (root_hobt.InvoiceDate IS NOT NULL)
GO