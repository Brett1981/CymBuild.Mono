SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_AutomatedInvoicing]
	(
		@UserId INT
	)
RETURNS TABLE
       --WITH SCHEMABINDING
AS
RETURN  SELECT  t.ID,
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
		CASE WHEN (o.Overdue_1_30 <> NULL OR o.Overdue_1_30 <> 0.0) THEN N'Overdue' ELSE N'' END AS IsOverdue
FROM    SFin.Transactions t
JOIN	SFin.TransactionCalculations tc ON (tc.ID = t.ID)
JOIN    SFin.TransactionTypes tt ON (tt.ID = t.TransactionTypeID)
JOIN	SCrm.Accounts a ON (a.ID = t.AccountID)
JOIN	SCore.Identities i ON (i.ID = t.SurveyorUserId)
JOIN	SJob.Jobs as j ON (j.ID = t.JobID)
CROSS APPLY SFin.tvf_OverdueInvoicesForJob(j.Guid) o
WHERE   (t.RowStatus  NOT IN (0, 254))
	AND	(t.Id > 0)
	AND (t.Batched  <> 1)
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