SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_AllTransactions] 
(
    @UserId INT
)
RETURNS TABLE
         --WITH SCHEMABINDING
AS
RETURN 
SELECT  t.ID,
        t.RowStatus,
        t.RowVersion,
        t.Guid,
        t.Number,
		t.Date,
		a.Name AS Account,
		tt.Name AS TransactionType,
		tc.Net,
		tc.Vat,
		tc.Gross,
		tc.Outstanding,
		t.SageTransactionReference,
		t.PurchaseOrderNumber,
		i.FullName AS Surveyor,
		t.Batched,
		CASE WHEN t.TransactionTypeID = 1 THEN
			(CASE WHEN (DueDetails.DueDate <= GETUTCDATE()) THEN N'Overdue' ELSE N'' END)
			ELSE '' END AS IsOverdue,
		CASE 
			WHEN (s.StatusCode IS NULL) THEN N'Not Sent' 
			ELSE s.StatusCode 
		END AS SageStatusCode,
		CASE 
			WHEN t.SageTransactionReference <> N'' THEN 1
			ELSE 0
		END AS HasSageReference
FROM    SFin.Transactions t
JOIN	SFin.TransactionCalculations tc ON (tc.ID = t.ID)
JOIN    SFin.TransactionTypes tt ON (tt.ID = t.TransactionTypeID)
JOIN	SCrm.Accounts a ON (a.ID = t.AccountID)
JOIN	SCore.Identities i ON (i.ID = t.SurveyorUserId)
JOIN	SJob.Jobs as j ON (j.ID = t.JobID)
LEFT JOIN SFin.TransactionSageSubmissionStatus s ON (s.TransactionGuid = t.Guid)
CROSS APPLY SFin.tvf_OverdueInvoicesForJob(j.Guid) o
OUTER APPLY (
    SELECT
        -- DueDate rule: ExpectedDate else InvoiceDate + CreditTerms.DueDays + 30 days (USE DATEADD/
        CASE WHEN  CAST(SUM(ISNULL(td.Gross, 0)) AS decimal(19,2)) <> 0 THEN
		CAST(
            COALESCE(
                CAST(tr.ExpectedDate AS date),
                DATEADD(DAY, ISNULL(ct.DueDays, 0),DATEADD(DAY, 30, ISNULL(CAST(t.[Date] AS DATETIME), 0)))
            )
        AS date)
		ELSE Null
		END
		AS DueDate
    FROM SFin.Transactions tr
    JOIN SFin.TransactionTypes tt ON tt.ID = tr.TransactionTypeID
    JOIN SJob.Jobs j ON j.ID = t.JobID
    LEFT JOIN SFin.TransactionDetails td
        ON td.TransactionID = t.ID
        AND td.RowStatus <> 254
    LEFT JOIN SFin.CreditTerms ct
        ON ct.ID = t.CreditTermsId
        AND ct.RowStatus <> 254
    WHERE
        j.ID = t.JobID
		AND tr.ID = t.ID
        AND tr.RowStatus <> 254
	GROUP BY tr.ExpectedDate, ct.DueDays) AS DueDetails
WHERE   (t.RowStatus  NOT IN (0, 254))
	AND	(t.Id > 0)
	AND	(EXISTS
				(
			SELECT
					1
			FROM
					SCore.ObjectSecurityForUser_CanRead(t.Guid, @UserId) oscr
				)
			)
		AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
			)
		)
GO