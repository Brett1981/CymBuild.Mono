USE [CymBuild_Dev]
GO

/****** Object:  UserDefinedFunction [SFin].[tvf_AllTransactions]    Script Date: 27/03/2026 14:11:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER   FUNCTION [SFin].[tvf_AllTransactions] 
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
		CASE WHEN (o.Overdue_1_30 IS NOT NULL OR o.Overdue_1_30 <> 0.0) THEN N'Overdue' ELSE N'' END AS IsOverdue
FROM    SFin.Transactions t
JOIN	SFin.TransactionCalculations tc ON (tc.ID = t.ID)
JOIN    SFin.TransactionTypes tt ON (tt.ID = t.TransactionTypeID)
JOIN	SCrm.Accounts a ON (a.ID = t.AccountID)
JOIN	SCore.Identities i ON (i.ID = t.SurveyorUserId)
JOIN	SJob.Jobs as j ON (j.ID = t.JobID)
CROSS APPLY SFin.tvf_OverdueInvoicesForJob(j.Guid) o
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


