SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[tvf_InvoiceSchedule_DetectedInstances]')
GO
/* =========================================================================================
   Phase 3 (Read-only): Combined detector output (union) for all instance types

   Notes / gates:
   - Manual invoicing column on SJob.Jobs: ManualOverRide.
   - Uses QuoteItems.CreatedJobId as the Quote→Job mapping (locked).
   - Applies Account On Hold + Manual Invoicing blocks at detection time (read-only exclusion).
   ========================================================================================= */
CREATE FUNCTION [SFin].[tvf_InvoiceSchedule_DetectedInstances]
(
    @AsOfUtcDate DATE = NULL
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
WITH
Params AS
(
    SELECT AsOfUtcDate = ISNULL(@AsOfUtcDate, CONVERT(date, GETUTCDATE()))
),

/* 1) Schedule → Quote → QuoteItems → JobId expansion (multi-job aware) */
ScheduleJobs AS
(
    SELECT
        s.ID   AS InvoiceScheduleId,
        s.Guid AS InvoiceScheduleGuid,
        qi.CreatedJobId AS JobId
    FROM SFin.InvoiceSchedules s
    INNER JOIN SSop.Quotes q
        ON q.ID = s.QuoteId
       AND q.RowStatus NOT IN (0,254)
    INNER JOIN SSop.QuoteItems qi
        ON qi.QuoteId = q.ID
       AND qi.RowStatus NOT IN (0,254)
       AND qi.CreatedJobId IS NOT NULL
    WHERE s.RowStatus NOT IN (0,254)
    GROUP BY s.ID, s.Guid, qi.CreatedJobId
),

/* 2) Apply read-only blocking filters at the job level */
EligibleScheduleJobs AS
(
    SELECT sj.InvoiceScheduleId, sj.InvoiceScheduleGuid, sj.JobId
    FROM ScheduleJobs sj
    INNER JOIN SJob.Jobs j
        ON j.ID = sj.JobId
       AND j.RowStatus NOT IN (0,254)
    LEFT JOIN SCrm.Accounts a
        ON j.FinanceAccountID = a.ID
       AND a.RowStatus NOT IN (0,254)
    INNER JOIN SCrm.AccountStatus acs
        ON a.AccountStatusID = acs.ID
       AND acs.RowStatus NOT IN (0,254)
    WHERE
        ISNULL(acs.IsHold, 0) = 0
        AND ISNULL(j.ManualInvoicingEnabled, 0) = 0  
),

/* 3) Activity completion detector (billable-only) */
ActivityDetected AS
(
    SELECT
        esj.InvoiceScheduleId,
        esj.InvoiceScheduleGuid,
        esj.JobId,
        InstanceType = N'Activity',
        InstanceKey  = CONCAT(N'ACT|', a.ID),
        CompletedDateTimeUTC =
            /* Needs-confirmation: a.EndDate is not UTC-labelled in schema;
               using it as the completion moment for now */
            TRY_CONVERT(datetime2(7), a.EndDate)
    FROM EligibleScheduleJobs esj
    INNER JOIN SJob.Activities a
        ON a.JobID = esj.JobId
       AND a.RowStatus NOT IN (0,254)
    INNER JOIN SJob.ActivityTypes aty
        ON aty.ID = a.ActivityTypeID
       AND aty.RowStatus NOT IN (0,254)
    INNER JOIN SJob.ActivityStatus ast
        ON ast.ID = a.ActivityStatusID
       AND ast.RowStatus NOT IN (0,254)
    WHERE
        aty.IsBillable = 1
        AND ast.IsCompleteStatus = 1
),

/* 4) Milestone completion detector */
MilestoneDetected AS
(
    SELECT
        esj.InvoiceScheduleId,
        esj.InvoiceScheduleGuid,
        esj.JobId,
        InstanceType = N'Milestone',
        InstanceKey  = CONCAT(N'MIL|', m.ID),
        CompletedDateTimeUTC = m.CompletedDateTimeUTC
    FROM EligibleScheduleJobs esj
    INNER JOIN SJob.Milestones m
        ON m.JobID = esj.JobId
       AND m.RowStatus NOT IN (0,254)
    WHERE
        m.IsNotApplicable = 0
        AND m.IsComplete = 1
        AND m.CompletedDateTimeUTC IS NOT NULL
),

/* 5) RIBA completion detector (future-ready; based on SJob.JobStages) */
RibaDetected AS
(
    SELECT
        esj.InvoiceScheduleId,
        esj.InvoiceScheduleGuid,
        esj.JobId,
        InstanceType = N'RIBA',
        InstanceKey  = CONCAT(N'RIBA|', js.ID),
        CompletedDateTimeUTC =
            COALESCE(
                /* Recommended future column */
                TRY_CONVERT(datetime2(7), js.CompletedDateTimeUTC),
                /* Fallback to EndDateTime if no explicit completion field exists */
                TRY_CONVERT(datetime2(7), js.EndDateTime)
            )
    FROM EligibleScheduleJobs esj
    INNER JOIN SJob.JobStages js
        ON js.JobID = esj.JobId
       AND js.RowStatus NOT IN (0,254)
    /* Completion rules still pending — for Phase 3 we emit rows with nullable completion datetime */
),

/* 6) Percentage “due” detector (Option A) */
PercentageDetected AS
(
    SELECT
        esj.InvoiceScheduleId,
        esj.InvoiceScheduleGuid,
        esj.JobId,
        InstanceType = N'Percentage',
        InstanceKey  = CONCAT(N'PCT|', pc.Guid),
        CompletedDateTimeUTC =
            CASE
                WHEN pc.OnDayOfMonth IS NOT NULL
                     AND pc.OnDayOfMonth <= (SELECT AsOfUtcDate FROM Params)
                THEN TRY_CONVERT(datetime2(7), pc.OnDayOfMonth)  -- date → midnight
                ELSE NULL
            END
    FROM EligibleScheduleJobs esj
    INNER JOIN SFin.InvoiceSchedulePercentageConfiguration pc
        ON pc.InvoiceScheduleId = esj.InvoiceScheduleId
       AND pc.RowStatus NOT IN (0,254)
),

/* 7) Monthly “due” detector (included for union completeness) */
MonthlyDetected AS
(
    SELECT
        esj.InvoiceScheduleId,
        esj.InvoiceScheduleGuid,
        esj.JobId,
        InstanceType = N'Monthly',
        InstanceKey  = CONCAT(N'MON|', mc.Guid),
        CompletedDateTimeUTC =
            CASE
                WHEN mc.OnDayOfMonth IS NOT NULL
                     AND mc.OnDayOfMonth <= (SELECT AsOfUtcDate FROM Params)
                THEN TRY_CONVERT(datetime2(7), mc.OnDayOfMonth)
                ELSE NULL
            END
    FROM EligibleScheduleJobs esj
    INNER JOIN SFin.InvoiceScheduleMonthConfiguration mc
        ON mc.InvoiceScheduleId = esj.InvoiceScheduleId
       AND mc.RowStatus NOT IN (0,254)
)

SELECT * FROM ActivityDetected
UNION ALL
SELECT * FROM MilestoneDetected
UNION ALL
SELECT * FROM RibaDetected
UNION ALL
SELECT * FROM PercentageDetected
UNION ALL
SELECT * FROM MonthlyDetected;
GO