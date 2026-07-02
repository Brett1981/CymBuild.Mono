SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[JobFinancialOverviewGet]')
GO

CREATE PROCEDURE [SJob].[JobFinancialOverviewGet]
    @UserId INT,
    @JobGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    IF (@UserId IS NULL OR @UserId <= 0)
    BEGIN
        SET @UserId = -1;
    END;

    DECLARE @JobId INT;

    SELECT
        @JobId = j.ID
    FROM SJob.Jobs AS j
    WHERE j.Guid = @JobGuid
      AND j.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
      );

    IF @JobId IS NULL
    BEGIN
        SELECT
            @JobGuid AS JobGuid,
            CAST(0.00 AS DECIMAL(19,2)) AS AgreedFeeTotal,
            CAST(0.00 AS DECIMAL(19,2)) AS AgreedFeeIncludingCap,
            CAST(0.00 AS DECIMAL(19,2)) AS ScheduledTotal,
            CAST(0.00 AS DECIMAL(19,2)) AS InvoiceRequestPendingTotal,
            CAST(0.00 AS DECIMAL(19,2)) AS InvoicedNet,
            CAST(0.00 AS DECIMAL(19,2)) AS InvoicedGross,
            CAST(0.00 AS DECIMAL(19,2)) AS PaidNet,
            CAST(0.00 AS DECIMAL(19,2)) AS PaidGross,
            CAST(0.00 AS DECIMAL(19,2)) AS RemainingNet,
            CONVERT(INT, 0) AS ActiveInvoiceScheduleCount,
            CONVERT(INT, 0) AS SystemGeneratedManualScheduleCount,
            CONVERT(INT, 0) AS PendingInvoiceRequestCount,
            CONVERT(INT, 0) AS ReconciliationRequiredInvoiceRequestCount,
            CONVERT(INT, 0) AS BlockedInvoiceRequestCount,
            CONVERT(BIT, 0) AS CanCreateReplacementInvoiceSchedule;
        RETURN;
    END;

    ;WITH FeeTotals AS
    (
        SELECT
            MAX(CASE WHEN fd.Stage = N'Total (ex. Fee Cap.)' THEN fd.Agreed END) AS AgreedFeeTotal,
            MAX(CASE WHEN fd.Stage = N'Total (inc. Fee Cap)' THEN fd.Agreed END) AS AgreedFeeIncludingCap,
            MAX(CASE WHEN fd.Stage = N'Total (inc. Fee Cap)' THEN fd.Remaining END) AS RemainingNetFromDrawdown
        FROM SJob.tvf_JobFeeDrawdown(@UserId, @JobGuid) AS fd
        WHERE fd.RowStatus NOT IN (0, 254)
    ),
    ScheduleTotals AS
    (
        SELECT
            SUM(CAST(ISNULL(s.Amount, 0.00) AS DECIMAL(19,2))) AS ScheduledTotal,
            COUNT_BIG(1) AS ActiveInvoiceScheduleCount,
            SUM(CASE WHEN s.IsSystemGeneratedManual = 1 THEN 1 ELSE 0 END) AS SystemGeneratedManualScheduleCount
        FROM SFin.tvf_JobInvoiceSchedules(@UserId, @JobGuid) AS s
        WHERE s.RowStatus NOT IN (0, 254)
    ),
    InvoiceRequestLines AS
    (
        SELECT
            ir.ID AS InvoiceRequestId,
            ir.ReconciliationRequired,
            ir.BlockedReason,
            ISNULL(iri.Net, 0.00) AS Net,
            CASE WHEN EXISTS
            (
                SELECT 1
                FROM SFin.TransactionDetails AS td
                WHERE td.InvoiceRequestItemId = iri.ID
                  AND td.RowStatus NOT IN (0, 254)
            ) THEN 1 ELSE 0 END AS HasProcessedLine
        FROM SFin.InvoiceRequests AS ir
        LEFT JOIN SFin.InvoiceRequestItems AS iri
            ON iri.InvoiceRequestId = ir.ID
           AND iri.RowStatus NOT IN (0, 254)
        WHERE ir.JobId = @JobId
          AND ir.RowStatus NOT IN (0, 254)
          AND ir.IsMerged = 0
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(ir.Guid, @UserId) AS oscr
          )
    ),
    InvoiceRequestSummary AS
    (
        SELECT
            COUNT(DISTINCT irl.InvoiceRequestId) AS PendingInvoiceRequestCount,
            SUM(CASE WHEN irl.HasProcessedLine = 0 THEN irl.Net ELSE 0.00 END) AS InvoiceRequestPendingTotal,
            COUNT(DISTINCT CASE WHEN irl.ReconciliationRequired = 1 THEN irl.InvoiceRequestId END) AS ReconciliationRequiredInvoiceRequestCount,
            COUNT(DISTINCT CASE WHEN NULLIF(LTRIM(RTRIM(irl.BlockedReason)), N'') IS NOT NULL THEN irl.InvoiceRequestId END) AS BlockedInvoiceRequestCount
        FROM InvoiceRequestLines AS irl
    ),
    TransactionTotals AS
    (
        SELECT
            CAST(SUM(ISNULL(td.Net, 0.00) * CASE WHEN tt.IsNegated = 1 THEN -1 ELSE 1 END) AS DECIMAL(19,2)) AS InvoicedNet,
            CAST(SUM(ISNULL(td.Gross, 0.00) * CASE WHEN tt.IsNegated = 1 THEN -1 ELSE 1 END) AS DECIMAL(19,2)) AS InvoicedGross
        FROM SFin.TransactionDetails AS td
        JOIN SFin.Transactions AS t
            ON t.ID = td.TransactionID
           AND t.JobID = @JobId
           AND t.RowStatus NOT IN (0, 254)
           AND ISNULL(t.Batched, 0) = 0
        JOIN SFin.TransactionTypes AS tt
            ON tt.ID = t.TransactionTypeID
           AND tt.RowStatus NOT IN (0, 254)
           AND tt.IsBank = 0
        WHERE td.RowStatus NOT IN (0, 254)
    ),
    PaidTotals AS
    (
        SELECT
            CAST(SUM(CASE WHEN ISNULL(tx_gross.TransactionGross, 0.00) = 0.00 THEN 0.00 ELSE ta.AllocatedAmount * (td.Net / tx_gross.TransactionGross) END) AS DECIMAL(19,2)) AS PaidNet,
            CAST(SUM(CASE WHEN ISNULL(tx_gross.TransactionGross, 0.00) = 0.00 THEN 0.00 ELSE ta.AllocatedAmount * (td.Gross / tx_gross.TransactionGross) END) AS DECIMAL(19,2)) AS PaidGross
        FROM SFin.TransactionDetails AS td
        JOIN SFin.Transactions AS t
            ON t.ID = td.TransactionID
           AND t.JobID = @JobId
           AND t.RowStatus NOT IN (0, 254)
           AND ISNULL(t.Batched, 0) = 0
        JOIN SFin.TransactionTypes AS tt
            ON tt.ID = t.TransactionTypeID
           AND tt.RowStatus NOT IN (0, 254)
           AND tt.IsBank = 0
        JOIN SFin.TransactionAllocations AS ta
            ON ta.TargetTransactionID = t.ID
           AND ta.RowStatus NOT IN (0, 254)
        OUTER APPLY
        (
            SELECT
                CAST(SUM(ISNULL(td2.Gross, 0.00)) AS DECIMAL(19,2)) AS TransactionGross
            FROM SFin.TransactionDetails AS td2
            WHERE td2.TransactionID = t.ID
              AND td2.RowStatus NOT IN (0, 254)
        ) AS tx_gross
        WHERE td.RowStatus NOT IN (0, 254)
    )
    SELECT
        @JobGuid AS JobGuid,
        CAST(ISNULL(ft.AgreedFeeTotal, 0.00) AS DECIMAL(19,2)) AS AgreedFeeTotal,
        CAST(ISNULL(ft.AgreedFeeIncludingCap, ft.AgreedFeeTotal) AS DECIMAL(19,2)) AS AgreedFeeIncludingCap,
        CAST(ISNULL(st.ScheduledTotal, 0.00) AS DECIMAL(19,2)) AS ScheduledTotal,
        CAST(ISNULL(irs.InvoiceRequestPendingTotal, 0.00) AS DECIMAL(19,2)) AS InvoiceRequestPendingTotal,
        CAST(ISNULL(tt.InvoicedNet, 0.00) AS DECIMAL(19,2)) AS InvoicedNet,
        CAST(ISNULL(tt.InvoicedGross, 0.00) AS DECIMAL(19,2)) AS InvoicedGross,
        CAST(ISNULL(pt.PaidNet, 0.00) AS DECIMAL(19,2)) AS PaidNet,
        CAST(ISNULL(pt.PaidGross, 0.00) AS DECIMAL(19,2)) AS PaidGross,
        CAST(ISNULL(ft.AgreedFeeIncludingCap, ft.AgreedFeeTotal) - ISNULL(tt.InvoicedNet, 0.00) AS DECIMAL(19,2)) AS RemainingNet,
        CONVERT(INT, ISNULL(st.ActiveInvoiceScheduleCount, 0)) AS ActiveInvoiceScheduleCount,
        CONVERT(INT, ISNULL(st.SystemGeneratedManualScheduleCount, 0)) AS SystemGeneratedManualScheduleCount,
        CONVERT(INT, ISNULL(irs.PendingInvoiceRequestCount, 0)) AS PendingInvoiceRequestCount,
        CONVERT(INT, ISNULL(irs.ReconciliationRequiredInvoiceRequestCount, 0)) AS ReconciliationRequiredInvoiceRequestCount,
        CONVERT(INT, ISNULL(irs.BlockedInvoiceRequestCount, 0)) AS BlockedInvoiceRequestCount,
        CONVERT(BIT, CASE WHEN ISNULL(st.ActiveInvoiceScheduleCount, 0) = 1 AND ISNULL(st.SystemGeneratedManualScheduleCount, 0) = 1 THEN 1 ELSE 0 END) AS CanCreateReplacementInvoiceSchedule
    FROM FeeTotals AS ft
    CROSS JOIN ScheduleTotals AS st
    CROSS JOIN InvoiceRequestSummary AS irs
    CROSS JOIN TransactionTotals AS tt
    CROSS JOIN PaidTotals AS pt;
END;
GO