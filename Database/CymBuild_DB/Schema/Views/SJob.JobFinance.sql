SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SJob].[JobFinance]
       --WITH SCHEMABINDING
AS 
SELECT	j.ID,
		TransactionTotals.Net AS InvoicedValue,
		CONVERT(DECIMAL(9, 2), ROUND(j.AgreedFee - TransactionTotals.Net, 2)) AS OutstandingFee
FROM	SJob.Jobs j
OUTER APPLY	
(
	SELECT	SUM(tc.Net * CASE WHEN tt.IsNegated = 1 THEN -1 ELSE 1 END) AS Net
	FROM	SFin.Transactions t
	JOIN	SFin.TransactionTypes tt ON (tt.ID = t.TransactionTypeID)
	JOIN	SFin.TransactionCalculations tc ON (t.ID = tc.ID)
	WHERE	(t.RowStatus NOT IN (0, 254))
		AND	(t.JobID = j.ID)
		AND	(tt.IsBank = 0)
) AS TransactionTotals
GO