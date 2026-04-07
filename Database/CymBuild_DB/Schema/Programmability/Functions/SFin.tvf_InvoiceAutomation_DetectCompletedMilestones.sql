SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[tvf_InvoiceAutomation_DetectCompletedMilestones]')
GO
--------------------------------------------------------------------------------
-- 2) Completed Milestones detector
--------------------------------------------------------------------------------
CREATE FUNCTION [SFin].[tvf_InvoiceAutomation_DetectCompletedMilestones]
(
    @AsOfUtc DATETIME2(7),
    @OrganisationalUnitId INT = NULL
)
RETURNS TABLE
AS
RETURN
WITH ScheduleJobs AS
(
    SELECT  s.ID AS InvoiceScheduleId,
            j.ID AS JobId,
            j.OrganisationalUnitID
    FROM SFin.InvoiceSchedules s
    JOIN SSop.Quotes q
        ON q.ID = s.QuoteId
       AND q.RowStatus NOT IN (0,254)
    JOIN SSop.QuoteItems qi
        ON qi.QuoteID = q.ID
       AND qi.RowStatus NOT IN (0,254)
       AND qi.CreatedJobId IS NOT NULL
    JOIN SJob.Jobs j
        ON j.ID = qi.CreatedJobId
       AND j.RowStatus NOT IN (0,254)
    WHERE s.RowStatus NOT IN (0,254)
      AND (@OrganisationalUnitId IS NULL OR j.OrganisationalUnitID = @OrganisationalUnitId)
),
CompletedMilestones AS
(
    SELECT  sj.InvoiceScheduleId,
            sj.JobId,
            m.ID AS MilestoneId,
            m.CompletedDateTimeUTC
    FROM ScheduleJobs sj
    JOIN SJob.Milestones m
        ON m.JobId = sj.JobId
       AND m.RowStatus NOT IN (0,254)
    WHERE m.IsComplete = 1
      AND m.CompletedDateTimeUTC IS NOT NULL
      AND m.CompletedDateTimeUTC <= @AsOfUtc
)
SELECT
    cm.InvoiceScheduleId,
    cm.JobId,
    CAST(N'MilestoneCompleted' AS NVARCHAR(50)) AS InstanceType,
    CAST(CONCAT(N'MIL:', cm.MilestoneId) AS NVARCHAR(200)) AS InstanceKey,
    cm.CompletedDateTimeUTC AS DetectedDateTimeUTC,
    CAST(N'Milestone' AS NVARCHAR(50)) AS SourceType,
    CAST(cm.MilestoneId AS INT) AS SourceIntId,
    CAST(NULL AS UNIQUEIDENTIFIER) AS SourceGuid,
    CAST(N'Milestone IsComplete=1 and CompletedDateTimeUTC <= @AsOfUtc' AS NVARCHAR(4000)) AS DebugMessage
FROM CompletedMilestones cm
WHERE NOT EXISTS
(
    SELECT 1
    FROM SFin.InvoiceScheduleTriggerInstances ti
    WHERE ti.RowStatus NOT IN (0,254)
      AND ti.InvoiceScheduleId = cm.InvoiceScheduleId
      AND ti.InstanceType = N'MilestoneCompleted'
      AND ti.InstanceKey  = CONCAT(N'MIL:', cm.MilestoneId)
);
GO