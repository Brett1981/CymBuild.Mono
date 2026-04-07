SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_AutomatedInvoicingKPI]
	(
		@UserId INT
	)
RETURNS TABLE
       --WITH SCHEMABINDING
AS
RETURN  

-- 1) Not Invoiced: request items with no transaction detail yet
WITH RequestItems AS
(
    SELECT
        iri.ID AS InvoiceRequestItemId,
        ir.JobId,
        CAST(iri.Net AS decimal(19,2)) AS NetAmount,
        ir.ExpectedDate
    FROM SFin.InvoiceRequests ir
    JOIN SFin.InvoiceRequestItems iri ON iri.InvoiceRequestId = ir.ID
    JOIN SJob.Jobs j ON j.ID = ir.JobId
    WHERE
      
         ir.RowStatus <> 254
        AND iri.RowStatus <> 254
        AND ISNULL(ir.IsZeroValuePlaceholder, 0) = 0
        AND ISNULL(ir.ReconciliationRequired, 0) = 0
),
InvoicedRequestItems AS
(
    SELECT DISTINCT td.InvoiceRequestItemId
    FROM SFin.TransactionDetails td
    JOIN SFin.Transactions t ON t.ID = td.TransactionID
    JOIN SJob.Jobs j ON j.ID = t.JobID
    WHERE
       
         t.RowStatus <> 254
        AND td.RowStatus <> 254
        AND td.InvoiceRequestItemId <> -1
),

-- 2) Transaction totals per transaction (gross), signed by TransactionType.IsNegated
TxnTotals AS
(
    SELECT
        t.ID AS TransactionID,
        t.JobID,
        t.TransactionTypeID,
        tt.Name AS TransactionTypeName,
        tt.IsNegated,
        t.Number,
        CAST(t.[Date] AS date) AS InvoiceDate,
        t.ExpectedDate,
        -- DueDate rule: ExpectedDate else InvoiceDate + CreditTerms.DueDays
        CAST(
            COALESCE(
                CAST(t.ExpectedDate AS date),
                DATEADD(DAY, ISNULL(ct.DueDays, 0), CAST(t.[Date] AS date))
            )
        AS date) AS DueDate,
        CAST(SUM(ISNULL(td.Gross, 0)) AS decimal(19,2)) AS TransactionGross
    FROM SFin.Transactions t
    JOIN SFin.TransactionTypes tt ON tt.ID = t.TransactionTypeID
    JOIN SJob.Jobs j ON j.ID = t.JobID
    LEFT JOIN SFin.TransactionDetails td
        ON td.TransactionID = t.ID
        AND td.RowStatus <> 254
    LEFT JOIN SFin.CreditTerms ct
        ON ct.ID = t.CreditTermsId
        AND ct.RowStatus <> 254
    WHERE
       
         t.RowStatus <> 254
    GROUP BY
        t.ID, t.JobID, t.TransactionTypeID, tt.Name, tt.IsNegated,
        t.Number, t.[Date], t.ExpectedDate, ct.DueDays
),
AllocToTarget AS
(
    SELECT
        ta.TargetTransactionID AS TransactionID,
        CAST(SUM(ISNULL(ta.AllocatedAmount, 0)) AS decimal(19,2)) AS AllocatedToTarget
    FROM SFin.TransactionAllocations ta
    WHERE ta.RowStatus <> 254
    GROUP BY ta.TargetTransactionID
),
	TxnBalances AS
	(
		SELECT
			x.TransactionID,
			x.TransactionTypeName,
			x.Number,
			x.InvoiceDate,
			x.ExpectedDate,
			x.DueDate,
			x.TransactionGross,

			SignedTotal =
				CAST(x.TransactionGross * CASE WHEN x.IsNegated = 1 THEN -1 ELSE 1 END AS decimal(19,2)),

			AllocatedToTarget =
				CAST(ISNULL(a.AllocatedToTarget, 0) AS decimal(19,2)),

			-- Allocation moves balance toward zero:
			OutstandingSigned =
				CAST(
					(x.TransactionGross * CASE WHEN x.IsNegated = 1 THEN -1 ELSE 1 END)
					- (ISNULL(a.AllocatedToTarget, 0)
					   * CASE
							WHEN (x.TransactionGross * CASE WHEN x.IsNegated = 1 THEN -1 ELSE 1 END) >= 0 THEN 1
							ELSE -1
						 END)
				AS decimal(19,2)),

			DaysOverdue =
				CASE
					WHEN x.DueDate IS NULL THEN NULL
					ELSE DATEDIFF(DAY, x.DueDate, CAST(GETDATE() AS date))
				END
		FROM TxnTotals x
		LEFT JOIN AllocToTarget a ON a.TransactionID = x.TransactionID
	),
OverdueBuckets AS
(
    SELECT
        BucketKey =
            CASE
                WHEN b.DaysOverdue BETWEEN 1  AND 30 THEN N'Overdue_1_30'
                WHEN b.DaysOverdue BETWEEN 31 AND 60 THEN N'Overdue_31_60'
                WHEN b.DaysOverdue BETWEEN 61 AND 90 THEN N'Overdue_61_90'
                WHEN b.DaysOverdue > 90              THEN N'Overdue_90Plus'
                ELSE NULL
            END,
        Amount = CAST(SUM(b.OutstandingSigned) AS decimal(19,2)),
        EarliestDueDate = MIN(b.DueDate),
        MaxDaysOverdue  = MAX(b.DaysOverdue),
        InvoiceCount    = COUNT(1)
    FROM TxnBalances b
    WHERE
        b.OutstandingSigned > 0
        AND b.DaysOverdue IS NOT NULL
        AND b.DaysOverdue > 0
    GROUP BY
        CASE
            WHEN b.DaysOverdue BETWEEN 1  AND 30 THEN N'Overdue_1_30'
            WHEN b.DaysOverdue BETWEEN 31 AND 60 THEN N'Overdue_31_60'
            WHEN b.DaysOverdue BETWEEN 61 AND 90 THEN N'Overdue_61_90'
            WHEN b.DaysOverdue > 90              THEN N'Overdue_90Plus'
            ELSE NULL
        END
)
SELECT
   
		  
  
	

	Total =
	(
		SELECT SUM(b.TransactionGross)
		FROM TxnBalances b
	),

	

	Average =
    (SELECT AVG(TransactionGross)
     FROM TxnBalances),

	 -- Counts of transactions
    PaidTransactionCount =
        (SELECT COUNT(*)
         FROM TxnBalances b
         WHERE b.AllocatedToTarget > 0),

    TotalOverdue =
        (SELECT COUNT(*)
         FROM TxnBalances b
         WHERE b.OutstandingSigned > 0
           AND b.DaysOverdue IS NOT NULL
           AND b.DaysOverdue > 0),

    TotalPending =
        (SELECT COUNT(*)
         FROM TxnBalances b
         WHERE b.OutstandingSigned > 0
           AND (b.DaysOverdue IS NULL OR b.DaysOverdue <= 0)),

	  TotalPaid =
        (SELECT COUNT(*)
         FROM TxnBalances b
         WHERE b.AllocatedToTarget > 0)

  

   

	 
					
GO