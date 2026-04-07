SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[tvf_InvoiceAutomation_Phase3Detections]')
GO
PRINT (N'Create function [SFin].[tvf_InvoiceAutomation_Phase3Detections]')
GO

/* =============================================================================
   SFin.tvf_InvoiceAutomation_Phase3Detections (corrected)

   Fixes:
   1) InvoiceScheduleActivityMilestoneConfiguration does NOT have InvoiceScheduleId.
      Correct join path is:
         SFin.InvoiceSchedules.ActivityMilestoneConfigurationId -> SFin.InvoiceScheduleActivityMilestoneConfiguration.ID

   2) Activity completion is locked to use EndDate if CompletedDateTimeUTC is NULL:
         COALESCE(a.CompletedDateTimeUTC, a.EndDate)

   Backward-compat behaviour:
   - If schedule.ActivityMilestoneConfigurationId is -1 or does not resolve to a config row,
     Activity/Milestone detections still work (no gating applied).
============================================================================= */
CREATE FUNCTION [SFin].[tvf_InvoiceAutomation_Phase3Detections]()
RETURNS TABLE
AS
RETURN
WITH
ScheduleJobScope AS
(
    SELECT DISTINCT
        sch.ID   AS InvoiceScheduleId,
        sch.Guid AS InvoiceScheduleGuid,
        qi.CreatedJobId AS JobId
    FROM SSop.QuoteItems qi
    JOIN SFin.InvoiceSchedules sch ON sch.ID = qi.InvoicingSchedule
    WHERE
        qi.RowStatus  NOT IN (0,254)
        AND sch.RowStatus NOT IN (0,254)
        AND qi.CreatedJobId NOT IN (-1, 0)
        AND qi.InvoicingSchedule NOT IN (-1, 0)
),
EligibleScope AS
(
    SELECT
        sjs.InvoiceScheduleId,
        sjs.InvoiceScheduleGuid,
        sjs.JobId,
        CAST(
            CASE
                WHEN ISNULL(j.ManualInvoicingEnabled, 0) = 1 THEN 1
                WHEN ISNULL(acs.IsHold, 0) = 1 THEN 1
                ELSE 0
            END
        AS bit) AS IsBlocked,
        sch.ActivityMilestoneConfigurationId,
        sch.RibaConfigurationId
    FROM ScheduleJobScope sjs
    JOIN SFin.InvoiceSchedules sch
        ON sch.ID = sjs.InvoiceScheduleId
       AND sch.RowStatus NOT IN (0,254)
    JOIN SJob.Jobs j
        ON j.ID = sjs.JobId
       AND j.RowStatus NOT IN (0,254)
    LEFT JOIN SCrm.Accounts a
        ON a.ID = j.FinanceAccountID
       AND a.RowStatus NOT IN (0,254)
    LEFT JOIN SCrm.AccountStatus acs
        ON acs.ID = a.AccountStatusID
       AND acs.RowStatus NOT IN (0,254)
)
-- ==========================
-- A) Activities (billable-only) - completion uses EndDate fallback (locked)
SELECT
    es.InvoiceScheduleId,
    es.InvoiceScheduleGuid,
    es.JobId,
    CAST(N'Activity' AS nvarchar(50)) AS InstanceType,
    CAST(N'ACT:' + CONVERT(nvarchar(50), act.ID) AS nvarchar(200)) AS InstanceKey,
    CAST(COALESCE(act.CompletedDateTimeUTC, act.EndDate) AS datetime2(7)) AS CompletedDateTimeUTC
FROM EligibleScope es
JOIN SJob.Activities act
    ON act.JobID = es.JobId
   AND act.RowStatus NOT IN (0,254)
JOIN SJob.ActivityTypes aty
    ON aty.ID = act.ActivityTypeID
JOIN SJob.ActivityStatus ats
    ON ats.ID = act.ActivityStatusID
LEFT JOIN SFin.InvoiceScheduleActivityMilestoneConfiguration amc
    ON amc.ID = es.ActivityMilestoneConfigurationId
   AND amc.RowStatus NOT IN (0,254)
WHERE
    es.IsBlocked = 0
    AND aty.IsBillable = 1
    AND ats.IsCompleteStatus = 1
    AND ISNULL(act.InvoicingValue, 0) > 0
    AND COALESCE(act.CompletedDateTimeUTC, act.EndDate) IS NOT NULL
    AND
    (
        -- Backward compatibility: no config row => allow
        amc.ID IS NULL
        OR ISNULL(amc.OnActivityCompletion, 0) = 1
        OR ISNULL(amc.OnActivityAndMilestonCompletion, 0) = 1
    )

UNION ALL

-- ==========================
-- B) Milestones (completion-only)
SELECT
    es.InvoiceScheduleId,
    es.InvoiceScheduleGuid,
    es.JobId,
    CAST(N'Milestone' AS nvarchar(50)) AS InstanceType,
    CAST(N'MS:' + CONVERT(nvarchar(50), m.ID) AS nvarchar(200)) AS InstanceKey,
    m.CompletedDateTimeUTC AS CompletedDateTimeUTC
FROM EligibleScope es
JOIN SJob.Milestones m
    ON m.JobID = es.JobId
   AND m.RowStatus NOT IN (0,254)
LEFT JOIN SFin.InvoiceScheduleActivityMilestoneConfiguration amc
    ON amc.ID = es.ActivityMilestoneConfigurationId
   AND amc.RowStatus NOT IN (0,254)
WHERE
    es.IsBlocked = 0
    AND ISNULL(m.IsNotApplicable, 0) = 0
    AND ISNULL(m.IsComplete, 0) = 1
    AND m.CompletedDateTimeUTC IS NOT NULL
    AND
    (
        -- Backward compatibility: no config row => allow
        amc.ID IS NULL
        OR ISNULL(amc.OnMilestoneCompletion, 0) = 1
        OR ISNULL(amc.OnActivityAndMilestonCompletion, 0) = 1
    )

UNION ALL

-- ==========================
-- C) RIBA (left as-is; you said ignore for now, but keep behaviour)
SELECT
    es.InvoiceScheduleId,
    es.InvoiceScheduleGuid,
    es.JobId,
    CAST(N'RIBA' AS nvarchar(50)) AS InstanceType,
    CAST(N'RIBA:' + CONVERT(nvarchar(50), js.ID) AS nvarchar(200)) AS InstanceKey,
    COALESCE(js.CompletedDateTimeUTC, js.EndDateTime) AS CompletedDateTimeUTC
FROM EligibleScope es
JOIN SJob.JobStages js
    ON js.JobID = es.JobId
   AND js.RowStatus NOT IN (0,254)
WHERE
    es.IsBlocked = 0
    AND COALESCE(js.CompletedDateTimeUTC, js.EndDateTime) IS NOT NULL;
GO