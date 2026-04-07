SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SFin].[TransactionCalculations]
   --WITH SCHEMABINDING
AS
SELECT		t.ID						AS ID,
			SUM (ISNULL (	td.Net,
							0
						)
				)						AS Net,
			SUM (ISNULL (	td.Vat,
							0
						)
				)						AS Vat,
			SUM (ISNULL (	td.Gross,
							0
						)
				)						AS Gross,
			SUM (ISNULL (	td.Gross,
							0
						)
				) - ISNULL (   TargetAllocationTotals.Amount,
							   0
						   ) - ISNULL (	  SourceAllocationTotals.Amount,
										  0
									  ) AS Outstanding,
			SUM (	ISNULL (td.Net,
							0
						   ) * CASE
								   WHEN tt.IsNegated = 1 THEN -1
								   ELSE 1
							   END
				)						AS RealNet,
			SUM (	ISNULL (td.Vat,
							0
						   ) * CASE
								   WHEN tt.IsNegated = 1 THEN -1
								   ELSE 1
							   END
				)						AS RealVat,
			SUM (	ISNULL (td.Gross,
							0
						   ) * CASE
								   WHEN tt.IsNegated = 1 THEN -1
								   ELSE 1
							   END
				)						AS RealGross,
			SUM (	ISNULL (td.Gross,
							0
						   ) * CASE
								   WHEN tt.IsNegated = 1 THEN -1
								   ELSE 1
							   END
				) - (ISNULL (	TargetAllocationTotals.Amount,
								0
							) * CASE
									WHEN tt.IsNegated = 1 THEN -1
									ELSE 1
								END
					) - (ISNULL (	SourceAllocationTotals.Amount,
									0
								) * CASE
										WHEN tt.IsNegated = 1 THEN -1
										ELSE 1
									END
						)				AS RealOutstanding,
			DATEADD(DAY, ct.DueDays, t.Date) AS DueDate
FROM		SFin.Transactions		AS t
JOIN		SFin.TransactionTypes	AS tt ON (tt.ID = t.TransactionTypeID)
JOIN		SFin.CreditTerms		AS ct ON (ct.ID = t.CreditTermsId)
LEFT JOIN	SFin.TransactionDetails AS td ON (td.TransactionID = t.ID)
										 AND (td.RowStatus NOT IN (0, 254))
OUTER APPLY
			(
				SELECT	SUM (ta.AllocatedAmount) AS Amount
				FROM	SFin.TransactionAllocations AS ta
				WHERE	(ta.TargetTransactionID = t.ID)
					AND (ta.RowStatus NOT IN (0, 254))
			)						AS TargetAllocationTotals
OUTER APPLY
			(
				SELECT	SUM (ta.AllocatedAmount) AS Amount
				FROM	SFin.TransactionAllocations AS ta
				WHERE	(ta.SourceTransactionID = t.ID)
					AND (ta.RowStatus NOT IN (0, 254))
			) AS SourceAllocationTotals
WHERE		(t.RowStatus NOT IN (0, 254))
GROUP BY	t.ID,
			SourceAllocationTotals.Amount,
			TargetAllocationTotals.Amount,
			tt.IsNegated,
			ct.DueDays,
			t.Date;

GO