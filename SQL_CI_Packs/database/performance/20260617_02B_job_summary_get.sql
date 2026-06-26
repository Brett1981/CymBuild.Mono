/*
    CymBuild Record Page Performance Patch 02B
    Adds lightweight read-only Jobs summary endpoints for fast page shell/header refresh.

    Deployment rules:
    - Source-controlled SQL only.
    - Idempotent CREATE OR ALTER.
    - Explicit columns only.
    - No workflow/status mutation; current status is resolved from latest SCore.DataObjectTransition.
    - RowStatus NOT IN (0,254) is used for active records.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE [SJob].[JobFinancialOverviewGet]
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

CREATE OR ALTER PROCEDURE [SJob].[JobSummaryGet]
    @UserId INT,
    @JobGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    IF (@UserId IS NULL OR @UserId <= 0)
    BEGIN
        SET @UserId = -1;
    END;

    DECLARE @Financial TABLE
    (
        JobGuid UNIQUEIDENTIFIER NOT NULL,
        AgreedFeeTotal DECIMAL(19,2) NOT NULL,
        AgreedFeeIncludingCap DECIMAL(19,2) NOT NULL,
        ScheduledTotal DECIMAL(19,2) NOT NULL,
        InvoiceRequestPendingTotal DECIMAL(19,2) NOT NULL,
        InvoicedNet DECIMAL(19,2) NOT NULL,
        InvoicedGross DECIMAL(19,2) NOT NULL,
        PaidNet DECIMAL(19,2) NOT NULL,
        PaidGross DECIMAL(19,2) NOT NULL,
        RemainingNet DECIMAL(19,2) NOT NULL,
        ActiveInvoiceScheduleCount INT NOT NULL,
        SystemGeneratedManualScheduleCount INT NOT NULL,
        PendingInvoiceRequestCount INT NOT NULL,
        ReconciliationRequiredInvoiceRequestCount INT NOT NULL,
        BlockedInvoiceRequestCount INT NOT NULL,
        CanCreateReplacementInvoiceSchedule BIT NOT NULL
    );

    INSERT @Financial
    (
        JobGuid,
        AgreedFeeTotal,
        AgreedFeeIncludingCap,
        ScheduledTotal,
        InvoiceRequestPendingTotal,
        InvoicedNet,
        InvoicedGross,
        PaidNet,
        PaidGross,
        RemainingNet,
        ActiveInvoiceScheduleCount,
        SystemGeneratedManualScheduleCount,
        PendingInvoiceRequestCount,
        ReconciliationRequiredInvoiceRequestCount,
        BlockedInvoiceRequestCount,
        CanCreateReplacementInvoiceSchedule
    )
    EXEC SJob.JobFinancialOverviewGet
        @UserId = @UserId,
        @JobGuid = @JobGuid;

    SELECT
        j.ID AS JobId,
        j.Guid AS JobGuid,
        CONVERT(INT, j.RowStatus) AS RowStatus,
        j.Number,
        CONCAT(j.Number, CASE WHEN NULLIF(LTRIM(RTRIM(j.JobDescription)), N'') IS NULL THEN N'' ELSE N' - ' + j.JobDescription END) AS DisplayTitle,
        j.JobDescription,
        ISNULL(acc.Name, N'') AS ClientName,
        ISNULL(surveyor.FullName, N'') AS SurveyorName,
        ISNULL(current_status.StatusID, -1) AS CurrentStatusId,
        ISNULL(current_status.StatusGuid, '00000000-0000-0000-0000-000000000000') AS CurrentStatusGuid,
        ISNULL(current_status.StatusName, N'') AS CurrentStatusName,
        CONVERT(BIT, j.IsActive) AS IsActive,
        CONVERT(BIT, j.IsComplete) AS IsComplete,
        CONVERT(BIT, j.IsCancelled) AS IsCancelled,
        CONVERT(BIT, j.CannotBeInvoiced) AS CannotBeInvoiced,
        CONVERT(INT, j.InvoiceProcessingMode) AS InvoiceProcessingMode,
        ISNULL(open_milestones.OpenMilestoneCount, 0) AS OpenMilestoneCount,
        ISNULL(open_activities.OpenActivityCount, 0) AS OpenActivityCount,
        ISNULL(open_actions.OpenActionCount, 0) AS OpenActionCount,
        ISNULL(fin.PendingInvoiceRequestCount, 0) AS PendingInvoiceRequestCount,
        ISNULL(fin.ActiveInvoiceScheduleCount, 0) AS ActiveInvoiceScheduleCount,
        ISNULL(fin.CanCreateReplacementInvoiceSchedule, CONVERT(BIT, 0)) AS CanCreateReplacementInvoiceSchedule,
        ISNULL(fin.AgreedFeeTotal, 0.00) AS AgreedFeeTotal,
        ISNULL(fin.AgreedFeeIncludingCap, 0.00) AS AgreedFeeIncludingCap,
        ISNULL(fin.ScheduledTotal, 0.00) AS ScheduledTotal,
        ISNULL(fin.InvoiceRequestPendingTotal, 0.00) AS InvoiceRequestPendingTotal,
        ISNULL(fin.InvoicedNet, 0.00) AS InvoicedNet,
        ISNULL(fin.InvoicedGross, 0.00) AS InvoicedGross,
        ISNULL(fin.PaidNet, 0.00) AS PaidNet,
        ISNULL(fin.PaidGross, 0.00) AS PaidGross,
        ISNULL(fin.RemainingNet, 0.00) AS RemainingNet,
        ISNULL(fin.SystemGeneratedManualScheduleCount, 0) AS SystemGeneratedManualScheduleCount,
        ISNULL(fin.ReconciliationRequiredInvoiceRequestCount, 0) AS ReconciliationRequiredInvoiceRequestCount,
        ISNULL(fin.BlockedInvoiceRequestCount, 0) AS BlockedInvoiceRequestCount
    FROM SJob.Jobs AS j
    LEFT JOIN SCrm.Accounts AS acc
        ON acc.ID = j.ClientAccountID
       AND acc.RowStatus NOT IN (0, 254)
    LEFT JOIN SCore.Identities AS surveyor
        ON surveyor.ID = j.SurveyorID
       AND surveyor.RowStatus NOT IN (0, 254)
    OUTER APPLY
    (
        SELECT TOP (1)
            dot.StatusID,
            ws.Guid AS StatusGuid,
            ws.Name AS StatusName
        FROM SCore.DataObjectTransition AS dot
        JOIN SCore.WorkflowStatus AS ws
            ON ws.ID = dot.StatusID
           AND ws.RowStatus NOT IN (0, 254)
        WHERE dot.DataObjectGuid = j.Guid
          AND dot.RowStatus NOT IN (0, 254)
        ORDER BY
            dot.DateTimeUTC DESC,
            dot.ID DESC
    ) AS current_status
    OUTER APPLY
    (
        SELECT COUNT_BIG(1) AS OpenMilestoneCount
        FROM SJob.Milestones AS m
        WHERE m.JobID = j.ID
          AND m.RowStatus NOT IN (0, 254)
          AND m.IsComplete = 0
    ) AS open_milestones
    OUTER APPLY
    (
        SELECT COUNT_BIG(1) AS OpenActivityCount
        FROM SJob.Activities AS a
        WHERE a.JobID = j.ID
          AND a.RowStatus NOT IN (0, 254)
          AND a.CompletedDateTimeUTC IS NULL
    ) AS open_activities
    OUTER APPLY
    (
        SELECT COUNT_BIG(1) AS OpenActionCount
        FROM SJob.Actions AS act
        WHERE act.JobID = j.ID
          AND act.RowStatus NOT IN (0, 254)
          AND act.IsComplete = 0
    ) AS open_actions
    LEFT JOIN @Financial AS fin
        ON fin.JobGuid = j.Guid
    WHERE j.Guid = @JobGuid
      AND j.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
      );
END;
GO
