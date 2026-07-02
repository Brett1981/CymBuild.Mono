SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[JobSummaryGet]')
GO

CREATE PROCEDURE [SJob].[JobSummaryGet]
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