SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobTransactions] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
         --WITH SCHEMABINDING
AS
RETURN 
SELECT	t.ID,
		t.Guid,
		t.RowStatus,
		t.Number,
		t.Date,
		tc.RealNet,
		tc.RealVat,
		tc.RealGross,
		tc.RealOutstanding,
		(tc.RealVat + tc.RealOutstanding) AS RealOutstandingWithVAT,
		tt.Name AS Type,
		i.FullName AS Surveyor,
		t.SageTransactionReference,
		ac.Name AS FinanceAccount,
		CASE
    WHEN tc.RealOutstanding = 0 
        THEN 'Paid'

    WHEN tc.RealOutstanding > 0 
         AND DATEDIFF(
                DAY,
                COALESCE(
                    CAST(t.ExpectedDate AS date),
                    DATEADD(DAY, ISNULL(ct.DueDays,0), CAST(t.[Date] AS date))
                ),
                CAST(GETDATE() AS date)
            ) > 0
        THEN 'Overdue'
    ELSE 'Outstanding'
END AS TransactionStatus
FROM	SFin.Transactions t
JOIN	SFin.TransactionCalculations tc ON (tc.Id = t.ID)
JOIN	SFin.TransactionTypes tt ON (tt.ID = t.TransactionTypeID)
JOIN	SJob.Jobs j ON (j.Id = t.JobID)
JOIN	SCore.Identities i ON (i.ID = t.SurveyorUserId)
JOIN    SCrm.Accounts AS ac ON (ac.ID = t.AccountID)
LEFT JOIN SFin.CreditTerms ct ON ct.ID = t.CreditTermsId AND ct.RowStatus <> 254
WHERE	(j.Guid = @ParentGuid)
GO