SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[tvf_InvoiceAutomation_DetectCompletedActivities]')
GO
--------------------------------------------------------------------------------
-- 1) Completed Activities detector
--------------------------------------------------------------------------------
CREATE FUNCTION [SFin].[tvf_InvoiceAutomation_DetectCompletedActivities]
(
    @AsOfUtc DATETIME2(7),
    @OrganisationalUnitId INT = NULL
)
RETURNS TABLE
AS
RETURN
WITH ScheduleJobs AS
(
    SELECT  s.ID                 AS InvoiceScheduleId,
            j.ID                 AS JobId,
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
CompletedActivities AS
(
    SELECT  sj.InvoiceScheduleId,
            sj.JobId,
            a.ID AS ActivityId,
            a.EndDate
    FROM ScheduleJobs sj
    JOIN SJob.Activities a
        ON a.JobId = sj.JobId
       AND a.RowStatus NOT IN (0,254)
    JOIN SJob.ActivityStatus ast
        ON ast.ID = a.ActivityStatusID
       AND ast.RowStatus NOT IN (0,254)
       AND ast.IsCompleteStatus = 1
    WHERE a.EndDate IS NOT NULL
      AND a.EndDate <= @AsOfUtc
)
SELECT
    ca.InvoiceScheduleId,
    ca.JobId,
    CAST(N'ActivityCompleted' AS NVARCHAR(50)) AS InstanceType,
    CAST(CONCAT(N'ACT:', ca.ActivityId) AS NVARCHAR(200)) AS InstanceKey,
    ca.EndDate AS DetectedDateTimeUTC,
    CAST(N'Activity' AS NVARCHAR(50)) AS SourceType,
    CAST(ca.ActivityId AS INT) AS SourceIntId,
    CAST(NULL AS UNIQUEIDENTIFIER) AS SourceGuid,
    CAST(N'Activity status is complete and CompletedDateTimeUTC <= @AsOfUtc' AS NVARCHAR(4000)) AS DebugMessage
FROM CompletedActivities ca
WHERE NOT EXISTS
(
    SELECT 1
    FROM SFin.InvoiceScheduleTriggerInstances ti
    WHERE ti.RowStatus NOT IN (0,254)
      AND ti.InvoiceScheduleId = ca.InvoiceScheduleId
      AND ti.InstanceType = N'ActivityCompleted'
      AND ti.InstanceKey  = CONCAT(N'ACT:', ca.ActivityId)
);
GO