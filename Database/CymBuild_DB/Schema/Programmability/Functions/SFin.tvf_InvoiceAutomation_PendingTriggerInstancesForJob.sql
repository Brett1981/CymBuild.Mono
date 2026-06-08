SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_InvoiceAutomation_PendingTriggerInstancesForJob]
(
    @JobId INT
)
RETURNS TABLE
AS
RETURN
(
    WITH ScheduleJobScope AS
    (
        SELECT DISTINCT
              qi.InvoicingSchedule AS InvoiceScheduleId
            , qi.CreatedJobId      AS JobId
        FROM SSop.QuoteItems qi
        WHERE qi.RowStatus NOT IN (0,254)
          AND qi.CreatedJobId = @JobId
          AND qi.CreatedJobId NOT IN (-1,0)
          AND qi.InvoicingSchedule NOT IN (-1,0)
    ),
    Candidate AS
    (
        SELECT
              sjs.JobId
            , sjs.InvoiceScheduleId
            , ti.Guid AS TriggerInstanceGuid
            , ti.InstanceType
            , ti.InstanceKey
            , ti.CompletedDateTimeUTC
        FROM ScheduleJobScope sjs
        JOIN SFin.InvoiceScheduleTriggerInstances ti
            ON ti.InvoiceScheduleId = sjs.InvoiceScheduleId
           AND ti.RowStatus NOT IN (0,254)
        WHERE ti.CompletedDateTimeUTC IS NOT NULL
    )
    SELECT
          c.JobId
        , c.InvoiceScheduleId
        , c.TriggerInstanceGuid
        , c.InstanceType
        , c.InstanceKey
        , c.CompletedDateTimeUTC
    FROM Candidate c
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SFin.InvoiceRequests r
        WHERE r.RowStatus NOT IN (0,254)
          AND r.JobId      = c.JobId
          AND r.SourceType = N'TriggerInstance'
          AND r.SourceGuid = c.TriggerInstanceGuid
    )
);
GO