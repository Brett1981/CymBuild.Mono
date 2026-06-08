SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [SFin].[tvf_OverdueInvoicesForJob]
(
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
WITH
RequestItems AS
(
    SELECT
        iri.ID AS InvoiceRequestItemId,
        ir.JobId,
        CAST(iri.Net AS decimal(19,2)) AS NetAmount,
        ir.ExpectedDate
    FROM SFin.InvoiceRequests AS ir
    INNER JOIN SFin.InvoiceRequestItems AS iri
        ON iri.InvoiceRequestId = ir.ID
        AND iri.RowStatus NOT IN (0,254)
    INNER JOIN SJob.Jobs AS j
        ON j.ID = ir.JobId
        AND j.RowStatus NOT IN (0,254)
    WHERE
        j.Guid = @ParentGuid
        AND ir.RowStatus NOT IN (0,254)
        AND ISNULL(ir.IsZeroValuePlaceholder, 0) = 0
        AND ISNULL(ir.ReconciliationRequired, 0) = 0
),
InvoicedRequestItems AS
(
    SELECT DISTINCT
        td.InvoiceRequestItemId
    FROM SFin.TransactionDetails AS td
    INNER JOIN SFin.Transactions AS t
        ON t.ID = td.TransactionID
        AND t.RowStatus NOT IN (0,254)
    INNER JOIN SJob.Jobs AS j
        ON j.ID = t.JobID
        AND j.RowStatus NOT IN (0,254)
    WHERE
        j.Guid = @ParentGuid
        AND td.RowStatus NOT IN (0,254)
        AND td.InvoiceRequestItemId <> -1
),
JobFee AS
(
    SELECT
        CAST(SUM(ISNULL(jf.Remaining, 0)) AS decimal(19,2)) AS Remaining
    FROM SJob.Job_FeeDrawdown AS jf
    WHERE
        jf.Guid = @ParentGuid
        AND jf.StageLabel LIKE N'%Total%'
),
TxnTotals AS
(
    SELECT
        t.ID AS TransactionID,
        t.JobID,
        t.TransactionTypeID,
        tt.Name AS TransactionTypeName,
        tt.IsNegated,
        tt.IsBank,
        t.Number,
        CAST(t.[Date] AS date) AS InvoiceDate,
        CAST(t.ExpectedDate AS date) AS ExpectedDate,

        CASE
            WHEN CAST(SUM(ISNULL(td.Gross, 0)) AS decimal(19,2)) <> 0
            THEN
                COALESCE(
                    CAST(t.ExpectedDate AS date),
                    CASE
                        WHEN t.[Date] IS NOT NULL
                        THEN DATEADD(DAY, ISNULL(ct.DueDays, 0) + 30, CAST(t.[Date] AS date))
                    END
                )
            ELSE NULL
        END AS DueDate,

        CAST(
            SUM(
                CASE
                    WHEN ISNULL(tt.IsNegated, 0) = 1
                        THEN -ISNULL(td.Gross, 0)
                    ELSE ISNULL(td.Gross, 0)
                END
            ) AS decimal(19,2)
        ) AS TransactionGross,

        CAST(
            SUM(
                CASE
                    WHEN ISNULL(tt.IsNegated, 0) = 1
                        THEN -ISNULL(td.Net, 0)
                    ELSE ISNULL(td.Net, 0)
                END
            ) AS decimal(19,2)
        ) AS TransactionNet,

        CAST(
            SUM(
                CASE
                    WHEN ISNULL(tt.IsNegated, 0) = 1
                        THEN -ISNULL(td.Vat, 0)
                    ELSE ISNULL(td.Vat, 0)
                END
            ) AS decimal(19,2)
        ) AS TransactionTax
    FROM SFin.Transactions AS t
    INNER JOIN SFin.TransactionTypes AS tt
        ON tt.ID = t.TransactionTypeID
        AND tt.RowStatus NOT IN (0,254)
        AND tt.IsActive = 1
    INNER JOIN SJob.Jobs AS j
        ON j.ID = t.JobID
        AND j.RowStatus NOT IN (0,254)
    LEFT JOIN SFin.TransactionDetails AS td
        ON td.TransactionID = t.ID
        AND td.RowStatus NOT IN (0,254)
    LEFT JOIN SFin.CreditTerms AS ct
        ON ct.ID = t.CreditTermsId
        AND ct.RowStatus NOT IN (0,254)
    WHERE
        j.Guid = @ParentGuid
        AND t.RowStatus NOT IN (0,254)
    GROUP BY
        t.ID,
        t.JobID,
        t.TransactionTypeID,
        tt.Name,
        tt.IsNegated,
        tt.IsBank,
        t.Number,
        t.[Date],
        t.ExpectedDate,
        ct.DueDays
),
AllocToTarget AS
(
    SELECT
        ta.TargetTransactionID AS TransactionID,
        CAST(SUM(ISNULL(ta.AllocatedAmount, 0)) AS decimal(19,2)) AS AllocatedToTarget
    FROM SFin.TransactionAllocations AS ta
    WHERE
        ta.RowStatus NOT IN (0,254)
    GROUP BY
        ta.TargetTransactionID
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
        x.TransactionNet,
        x.TransactionTax,

        CAST(x.TransactionGross AS decimal(19,2)) AS SignedTotal,

        CAST(ISNULL(a.AllocatedToTarget, 0) AS decimal(19,2)) AS AllocatedToTarget,

        CAST(
            CASE
                WHEN x.TransactionGross > 0
                    THEN x.TransactionGross - ISNULL(a.AllocatedToTarget, 0)
                ELSE x.TransactionGross
            END
        AS decimal(19,2)) AS OutstandingSigned,

        CAST(
            CASE
                WHEN x.TransactionGross > 0 AND x.TransactionGross <> 0
                    THEN x.TransactionNet
                         - (
                            ISNULL(a.AllocatedToTarget, 0)
                            * (x.TransactionNet / NULLIF(x.TransactionGross, 0))
                           )
                ELSE x.TransactionNet
            END
        AS decimal(19,2)) AS OutstandingWithoutVAT,

        CASE
            WHEN x.DueDate IS NULL THEN NULL
            ELSE DATEDIFF(DAY, x.DueDate, CAST(GETDATE() AS date))
        END AS DaysOverdue
    FROM TxnTotals AS x
    LEFT JOIN AllocToTarget AS a
        ON a.TransactionID = x.TransactionID
),
OverdueBuckets AS
(
    SELECT
        CASE
            WHEN b.DaysOverdue BETWEEN 1  AND 30 THEN N'Overdue_1_30'
            WHEN b.DaysOverdue BETWEEN 31 AND 60 THEN N'Overdue_31_60'
            WHEN b.DaysOverdue BETWEEN 61 AND 90 THEN N'Overdue_61_90'
            WHEN b.DaysOverdue > 90              THEN N'Overdue_90Plus'
            ELSE NULL
        END AS BucketKey,
        CAST(SUM(b.OutstandingSigned) AS decimal(19,2)) AS Amount,
        MIN(b.DueDate) AS EarliestDueDate,
        MAX(b.DaysOverdue) AS MaxDaysOverdue,
        COUNT(1) AS InvoiceCount
    FROM TxnBalances AS b
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
    CAST(ISNULL(
        (
            SELECT SUM(ri.NetAmount)
            FROM RequestItems AS ri
            LEFT JOIN InvoicedRequestItems AS ii
                ON ii.InvoiceRequestItemId = ri.InvoiceRequestItemId
            WHERE ii.InvoiceRequestItemId IS NULL
        ), 0
    ) AS decimal(19,2)) AS NotInvoicedAmount,

    CAST(ISNULL(
        (
            SELECT SUM(
                CASE
                    WHEN b.OutstandingSigned > 0 THEN b.OutstandingSigned
                    ELSE 0
                END
            )
            FROM TxnBalances AS b
        ), 0
    ) AS decimal(19,2)) AS OutstandingAmount,

    CAST(ISNULL(
        (
            SELECT SUM(
                CASE
                    WHEN b.OutstandingWithoutVAT > 0 THEN b.OutstandingWithoutVAT
                    ELSE 0
                END
            )
            FROM TxnBalances AS b
        ), 0
    ) AS decimal(19,2)) AS OutstandingAmountWithoutVAT,

    CAST(ISNULL(
        (
            SELECT jf.Remaining
            FROM JobFee AS jf
        ), 0
    ) AS decimal(19,2)) AS RemainingAmount,

    CAST(ISNULL(
        (
            SELECT SUM(CASE WHEN ob.BucketKey = N'Overdue_1_30' THEN ob.Amount ELSE 0 END)
            FROM OverdueBuckets AS ob
        ), 0
    ) AS decimal(19,2)) AS Overdue_1_30,

    CAST(ISNULL(
        (
            SELECT SUM(CASE WHEN ob.BucketKey = N'Overdue_31_60' THEN ob.Amount ELSE 0 END)
            FROM OverdueBuckets AS ob
        ), 0
    ) AS decimal(19,2)) AS Overdue_31_60,

    CAST(ISNULL(
        (
            SELECT SUM(CASE WHEN ob.BucketKey = N'Overdue_61_90' THEN ob.Amount ELSE 0 END)
            FROM OverdueBuckets AS ob
        ), 0
    ) AS decimal(19,2)) AS Overdue_61_90,

    CAST(ISNULL(
        (
            SELECT SUM(CASE WHEN ob.BucketKey = N'Overdue_90Plus' THEN ob.Amount ELSE 0 END)
            FROM OverdueBuckets AS ob
        ), 0
    ) AS decimal(19,2)) AS Overdue_90Plus,

    (
        SELECT
            ob.BucketKey AS [bucket],
            ob.Amount AS [amount],
            ob.EarliestDueDate AS [earliestDueDate],
            ob.MaxDaysOverdue AS [maxDaysOverdue],
            ob.InvoiceCount AS [invoiceCount]
        FROM OverdueBuckets AS ob
        WHERE ob.BucketKey IS NOT NULL
        FOR JSON PATH
    ) AS OverdueBucketsJson;
GO