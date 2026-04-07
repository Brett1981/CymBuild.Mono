SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[tvf_InvoiceAutomation_DetectPercentageDue]')
GO
--------------------------------------------------------------------------------
-- 4) Percentage due detector (date-driven, needs confirmation of “due” rules)
--------------------------------------------------------------------------------
CREATE FUNCTION [SFin].[tvf_InvoiceAutomation_DetectPercentageDue]
(
    @AsOfDate DATE,
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
DueRows AS
(
    SELECT  sj.InvoiceScheduleId,
            sj.JobId,
            pc.ID AS PercentageConfigId,
            pc.PeriodNumber,
            pc.Percentage,
            pc.OnDayOfMonth
    FROM ScheduleJobs sj
    JOIN SFin.InvoiceSchedulePercentageConfiguration pc
        ON pc.InvoiceScheduleId = sj.InvoiceScheduleId
       AND pc.RowStatus NOT IN (0,254)
    WHERE pc.OnDayOfMonth IS NOT NULL
      AND pc.OnDayOfMonth <= @AsOfDate
)
SELECT
    dr.InvoiceScheduleId,
    dr.JobId,
    CAST(N'PercentageDue' AS NVARCHAR(50)) AS InstanceType,
    CAST(CONCAT(N'PCT:', dr.PercentageConfigId) AS NVARCHAR(200)) AS InstanceKey,
    CAST(CONVERT(DATETIME2(7), dr.OnDayOfMonth) AS DATETIME2(7)) AS DetectedDateTimeUTC,
    CAST(N'PercentageConfig' AS NVARCHAR(50)) AS SourceType,
    CAST(dr.PercentageConfigId AS INT) AS SourceIntId,
    CAST(NULL AS UNIQUEIDENTIFIER) AS SourceGuid,
    CAST(CONCAT(N'OnDayOfMonth <= @AsOfDate; Percentage=', dr.Percentage, N'; Period=', dr.PeriodNumber,
                N'. (Due-rule needs confirmation: date-driven vs progress-driven)') AS NVARCHAR(4000)) AS DebugMessage
FROM DueRows dr
WHERE NOT EXISTS
(
    SELECT 1
    FROM SFin.InvoiceScheduleTriggerInstances ti
    WHERE ti.RowStatus NOT IN (0,254)
      AND ti.InvoiceScheduleId = dr.InvoiceScheduleId
      AND ti.InstanceType = N'PercentageDue'
      AND ti.InstanceKey  = CONCAT(N'PCT:', dr.PercentageConfigId)
);
GO