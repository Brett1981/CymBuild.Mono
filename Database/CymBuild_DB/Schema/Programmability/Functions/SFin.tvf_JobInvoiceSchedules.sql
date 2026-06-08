SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create function [SFin].[tvf_JobInvoiceSchedules]')
GO

CREATE FUNCTION [SFin].[tvf_JobInvoiceSchedules]
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
(
    WITH JobContext AS
    (
        SELECT
            jex.ID       AS JobId,
            j.SurveyorID AS SurveyorId,
            q.ID         AS QuoteId
        FROM SJob.Job_ExtendedInfo AS jex
        JOIN SJob.Jobs AS j
            ON j.ID = jex.ID
        JOIN SSop.Quotes AS q
            ON q.Guid = jex.QuoteGuid
        WHERE jex.Guid = @ParentGuid
    ),

    AssignedSchedules AS
    (
        SELECT DISTINCT
            qi.InvoicingSchedule AS InvoiceScheduleId
        FROM JobContext AS jc
        JOIN SSop.QuoteItems AS qi
            ON qi.QuoteId = jc.QuoteId
           AND qi.CreatedJobId = jc.JobId
        WHERE qi.RowStatus NOT IN (0, 254)
          AND ISNULL(qi.InvoicingSchedule, -1) NOT IN (-1, 0)
    ),

    ScheduleBase AS
    (
        SELECT
            invs.ID,
            invs.RowStatus,
            invs.RowVersion,
            invs.Guid,
            invs.Name,
            invs.DescriptionOfWork,
            invs.Amount,
            invs.TriggerId,
            invs.ExpectedDate,
            invs.QuoteId,
            invs.RibaConfigurationId,
            invs.ActivityMilestoneConfigurationId
        FROM SFin.InvoiceSchedules AS invs
        JOIN AssignedSchedules AS ass
            ON ass.InvoiceScheduleId = invs.ID
        WHERE invs.RowStatus NOT IN (0, 254)
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(invs.Guid, @UserId) AS oscr
          )
    ),

    QuoteItemTotals AS
    (
        SELECT
            qi.InvoicingSchedule AS InvoiceScheduleId,
            SUM(ISNULL(qi.Net, 0.00)) AS QuoteItemNetTotal
        FROM JobContext AS jc
        JOIN SSop.QuoteItems AS qi
            ON qi.QuoteId = jc.QuoteId
           AND qi.CreatedJobId = jc.JobId
        WHERE qi.RowStatus NOT IN (0, 254)
          AND ISNULL(qi.InvoicingSchedule, -1) NOT IN (-1, 0)
        GROUP BY
            qi.InvoicingSchedule
    ),

    ActivityTotals AS
    (
        SELECT
            sb.ID AS InvoiceScheduleId,
            SUM
            (
                CASE
                    WHEN ISNULL(a.InvoicingQuantity, 0.00) = 0.00
                        THEN ISNULL(a.InvoicingValue, 0.00)
                    ELSE
                        ISNULL(a.InvoicingQuantity, 0.00) *
                        CASE
                            WHEN ISNULL(a.InvoicingValue, 0.00) = 0.00 THEN 1.00
                            ELSE a.InvoicingValue
                        END
                END
            ) AS ActivityAmount
        FROM ScheduleBase AS sb
        CROSS JOIN JobContext AS jc
        JOIN SJob.Activities AS a
            ON a.JobID = jc.JobId
        WHERE a.RowStatus NOT IN (0, 254)
        GROUP BY
            sb.ID
    ),

    JobSurveyorRate AS
    (
        SELECT
            jc.JobId,
            CAST
            (
                CASE
                    WHEN ISNULL(i.BillableRate, 0.00) = 0.00 THEN 1.00
                    ELSE i.BillableRate
                END
                AS DECIMAL(19, 2)
            ) AS BillableRate
        FROM JobContext AS jc
        LEFT JOIN SCore.Identities AS i
            ON i.ID = jc.SurveyorId
           AND i.RowStatus NOT IN (0, 254)
    ),

    MilestoneHoursTotals AS
    (
        SELECT
            sb.ID AS InvoiceScheduleId,
            SUM
            (
                CASE
                    WHEN ISNULL(m.QuotedHours, 0.00) > 0.00
                        THEN ISNULL(m.QuotedHours, 0.00) * ISNULL(jsr.BillableRate, 1.00)
                    ELSE 0.00
                END
            ) AS MilestoneHoursAmount
        FROM ScheduleBase AS sb
        CROSS JOIN JobContext AS jc
        LEFT JOIN JobSurveyorRate AS jsr
            ON jsr.JobId = jc.JobId
        JOIN SJob.Milestones AS m
            ON m.JobID = jc.JobId
        WHERE m.RowStatus NOT IN (0, 254)
        GROUP BY
            sb.ID
    ),

    MonthTotals AS
    (
        SELECT
            mon.InvoiceScheduleId,
            SUM(ISNULL(mon.Amount, 0.00)) AS TotalMonthAmount
        FROM SFin.InvoiceScheduleMonthConfiguration AS mon
        WHERE mon.RowStatus NOT IN (0, 254)
        GROUP BY
            mon.InvoiceScheduleId
    ),

    PercentageTotals AS
    (
        SELECT
            pct.InvoiceScheduleId,
            MAX(ISNULL(pct.Percentage, 0.00)) AS Percentage
        FROM SFin.InvoiceSchedulePercentageConfiguration AS pct
        WHERE pct.RowStatus NOT IN (0, 254)
        GROUP BY
            pct.InvoiceScheduleId
    ),

    ActivityMilestoneConfig AS
    (
        SELECT
            amc.ID,
            MAX(CASE WHEN amc.OnActivityCompletion = 1 THEN 1 ELSE 0 END) AS OnActivityCompletion,
            MAX(CASE WHEN amc.OnMilestoneCompletion = 1 THEN 1 ELSE 0 END) AS OnMilestoneCompletion,
            MAX(CASE WHEN amc.OnActivityAndMilestonCompletion = 1 THEN 1 ELSE 0 END) AS OnActivityAndMilestonCompletion
        FROM SFin.InvoiceScheduleActivityMilestoneConfiguration AS amc
        WHERE amc.RowStatus NOT IN (0, 254)
        GROUP BY
            amc.ID
    ),

    RibaConfigs AS
    (
        SELECT
            riba.ID
        FROM SFin.InvoiceScheduleRibaConfiguration AS riba
        WHERE riba.RowStatus NOT IN (0, 254)
        GROUP BY
            riba.ID
    )

    SELECT
        sb.ID,
        sb.RowStatus,
        sb.RowVersion,
        sb.Guid,
        sb.Name,
        sb.DescriptionOfWork,
        CAST
        (
            CASE
                WHEN pct.InvoiceScheduleId IS NOT NULL
                    THEN ISNULL(qit.QuoteItemNetTotal, 0.00)
                         * (ISNULL(pct.Percentage, 0.00) / 100.00)

                WHEN mon.InvoiceScheduleId IS NOT NULL
                    THEN ISNULL(mon.TotalMonthAmount, 0.00)

                WHEN amc.ID IS NOT NULL
                     AND amc.OnActivityAndMilestonCompletion = 1
                    THEN ISNULL(atl.ActivityAmount, 0.00)
                         + CASE
                               WHEN ISNULL(mht.MilestoneHoursAmount, 0.00) > 0.00
                                   THEN ISNULL(mht.MilestoneHoursAmount, 0.00)
                               ELSE ISNULL(qit.QuoteItemNetTotal, 0.00)
                           END

                WHEN amc.ID IS NOT NULL
                     AND amc.OnActivityCompletion = 1
                    THEN ISNULL(atl.ActivityAmount, 0.00)

                WHEN amc.ID IS NOT NULL
                     AND amc.OnMilestoneCompletion = 1
                    THEN CASE
                             WHEN ISNULL(mht.MilestoneHoursAmount, 0.00) > 0.00
                                 THEN ISNULL(mht.MilestoneHoursAmount, 0.00)
                             ELSE ISNULL(qit.QuoteItemNetTotal, 0.00)
                         END

                WHEN riba.ID IS NOT NULL
                    THEN ISNULL(qit.QuoteItemNetTotal, 0.00)

                ELSE ISNULL(sb.Amount, 0.00)
            END
            AS DECIMAL(19, 2)
        ) AS Amount,
        ist.Name AS TriggerId,
        sb.ExpectedDate,
        CAST
        (
            CASE
                WHEN sb.Name = N'Manual'
                 AND sb.DescriptionOfWork = N'System generated manual invoice schedule created during job creation.'
                 AND ist.Name = N'Manual'
                THEN 1
                ELSE 0
            END
            AS bit
        ) AS IsSystemGeneratedManual
    FROM ScheduleBase AS sb
    JOIN SFin.InvoiceScheduleTrigger AS ist
        ON ist.ID = sb.TriggerId
       AND ist.RowStatus NOT IN (0, 254)
    LEFT JOIN PercentageTotals AS pct
        ON pct.InvoiceScheduleId = sb.ID
    LEFT JOIN MonthTotals AS mon
        ON mon.InvoiceScheduleId = sb.ID
    LEFT JOIN ActivityMilestoneConfig AS amc
        ON amc.ID = sb.ActivityMilestoneConfigurationId
    LEFT JOIN RibaConfigs AS riba
        ON riba.ID = sb.RibaConfigurationId
    LEFT JOIN QuoteItemTotals AS qit
        ON qit.InvoiceScheduleId = sb.ID
    LEFT JOIN ActivityTotals AS atl
        ON atl.InvoiceScheduleId = sb.ID
    LEFT JOIN MilestoneHoursTotals AS mht
        ON mht.InvoiceScheduleId = sb.ID
);
GO