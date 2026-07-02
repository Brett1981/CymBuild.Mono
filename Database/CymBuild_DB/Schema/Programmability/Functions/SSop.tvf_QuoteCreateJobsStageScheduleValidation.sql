SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SSop].[tvf_QuoteCreateJobsStageScheduleValidation]')
GO
PRINT (N'Create function [SSop].[tvf_QuoteCreateJobsStageScheduleValidation]')
GO

CREATE FUNCTION [SSop].[tvf_QuoteCreateJobsStageScheduleValidation]
(
    @QuoteGuid UNIQUEIDENTIFIER
)
RETURNS @Validation TABLE
(
    SeverityCode NVARCHAR(1) NOT NULL,
    ValidationCode NVARCHAR(100) NOT NULL,
    QuoteItemStageID INT NOT NULL,
    InvoiceScheduleID INT NOT NULL,
    StageName NVARCHAR(500) NOT NULL,
    QuoteItemStageTotal DECIMAL(19, 2) NOT NULL,
    InvoiceScheduleStageTotal DECIMAL(19, 2) NULL,
    Message NVARCHAR(2000) NOT NULL
)
AS
BEGIN
    DECLARE @QuoteID INT = -1;

    SELECT @QuoteID = q.ID
    FROM SSop.Quotes AS q
    WHERE q.Guid = @QuoteGuid
      AND q.RowStatus NOT IN (0,254);

    ;WITH EligibleQuoteItems AS
    (
        SELECT
            CONVERT(INT, qi.ID) AS QuoteItemID,
            qi.QuoteId,
            ISNULL(resolvedInvoiceSchedule.InvoiceScheduleID, -1) AS InvoiceScheduleID,
            CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END AS QuoteItemStageID,
            CONVERT(DECIMAL(19,2), qit.LineNet) AS LineNet,
            qi.SortOrder,
            CASE WHEN prod.NeverConsolidate = 1 OR qi.DoNotConsolidateJob = 1 THEN CONVERT(BIT,1) ELSE CONVERT(BIT,0) END AS IsIndividualJob,
            CASE WHEN prod.CreatedJobType > 0 THEN prod.CreatedJobType ELSE es.JobTypeId END AS JobTypeID,
            ISNULL(jt.Name, N'Unknown Job Type') AS JobTypeName
        FROM SSop.QuoteItems AS qi
        JOIN SSop.QuoteItemTotals AS qit
            ON qit.ID = qi.ID
        JOIN SSop.Quotes AS q
            ON q.ID = qi.QuoteId
        JOIN SSop.EnquiryServices AS es
            ON es.ID = q.EnquiryServiceID
        JOIN SProd.Products AS prod
            ON prod.ID = qi.ProductId
        LEFT JOIN SJob.JobTypes AS jt
            ON jt.ID = CASE WHEN prod.CreatedJobType > 0 THEN prod.CreatedJobType ELSE es.JobTypeId END
        LEFT JOIN SSop.InvoiceSchedules AS quoteItemSchedule
            ON quoteItemSchedule.ID = qi.InvoicingSchedule
           AND quoteItemSchedule.RowStatus NOT IN (0,254)
        OUTER APPLY
        (
            SELECT TOP (1)
                invs.ID AS InvoiceScheduleID
            FROM SFin.InvoiceSchedules AS invs
            WHERE invs.QuoteId = q.ID
              AND invs.RowStatus NOT IN (0,254)
              AND ISNULL(qi.InvoicingSchedule, -1) > 0
              AND
              (
                     invs.ID = qi.InvoicingSchedule
                  OR
                     (
                         quoteItemSchedule.ID IS NOT NULL
                     AND LTRIM(RTRIM(invs.Name)) = LTRIM(RTRIM(quoteItemSchedule.Name))
                     )
              )
              AND
              (
                  EXISTS
                  (
                      SELECT 1
                      FROM SFin.InvoiceScheduleMonthConfiguration AS mc
                      WHERE mc.InvoiceScheduleId = invs.ID
                        AND mc.RowStatus NOT IN (0,254)
                  )
                  OR EXISTS
                  (
                      SELECT 1
                      FROM SFin.InvoiceSchedulePercentageConfiguration AS pc
                      WHERE pc.InvoiceScheduleId = invs.ID
                        AND pc.RowStatus NOT IN (0,254)
                  )
              )
            ORDER BY
                CASE
                    WHEN invs.ID = qi.InvoicingSchedule THEN 0
                    WHEN quoteItemSchedule.ID IS NOT NULL
                     AND LTRIM(RTRIM(invs.Name)) = LTRIM(RTRIM(quoteItemSchedule.Name)) THEN 1
                    ELSE 2
                END,
                invs.ID
        ) AS resolvedInvoiceSchedule
        WHERE qi.QuoteId = @QuoteID
          AND qi.RowStatus NOT IN (0,254)
          AND qi.Quantity > 0
          AND ISNULL(qi.CreatedJobId, -1) <= 0
          AND CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END > 0
    ),
    JobGroupedQuoteItems AS
    (
        SELECT
            eqi.QuoteItemID,
            eqi.QuoteId,
            eqi.InvoiceScheduleID,
            eqi.QuoteItemStageID,
            eqi.LineNet,
            eqi.SortOrder,
            eqi.IsIndividualJob,
            eqi.JobTypeID,
            eqi.JobTypeName,
            CASE
                WHEN eqi.IsIndividualJob = 1 THEN N'QI:' + CONVERT(NVARCHAR(20), eqi.QuoteItemID)
                ELSE N'CON:' + CONVERT(NVARCHAR(20), eqi.JobTypeID)
            END AS JobGroupKey,
            CASE
                WHEN eqi.IsIndividualJob = 1 THEN N'Quote Item ' + CONVERT(NVARCHAR(20), eqi.QuoteItemID)
                ELSE N'Consolidated Job Group - ' + eqi.JobTypeName
            END AS JobGroupName
        FROM EligibleQuoteItems AS eqi
    ),
    QuoteJobGroupTotals AS
    (
        SELECT
            jgqi.JobGroupKey,
            jgqi.JobGroupName,
            SUM(jgqi.LineNet) AS QuoteItemJobGroupTotal
        FROM JobGroupedQuoteItems AS jgqi
        WHERE jgqi.InvoiceScheduleID > 0
        GROUP BY
            jgqi.JobGroupKey,
            jgqi.JobGroupName
    ),
    JobGroupInvoiceSchedules AS
    (
        SELECT DISTINCT
            jgqi.JobGroupKey,
            jgqi.InvoiceScheduleID
        FROM JobGroupedQuoteItems AS jgqi
        WHERE jgqi.InvoiceScheduleID > 0
    ),
    InvoiceScheduleConfiguredLineTotals AS
    (
        SELECT
            sch.ID AS InvoiceScheduleID,
            SUM(CONVERT(DECIMAL(19,2), monthconf.Amount)) AS InvoiceScheduleLineTotal
        FROM JobGroupInvoiceSchedules AS jgis
        JOIN SFin.InvoiceSchedules AS sch
            ON sch.ID = jgis.InvoiceScheduleID
        JOIN SFin.InvoiceScheduleMonthConfiguration AS monthconf
            ON monthconf.InvoiceScheduleId = sch.ID
        WHERE sch.RowStatus NOT IN (0,254)
          AND monthconf.RowStatus NOT IN (0,254)
        GROUP BY sch.ID

        UNION ALL

        SELECT
            sch.ID AS InvoiceScheduleID,
            SUM
            (
                CONVERT
                (
                    DECIMAL(19,2),
                    ROUND(sch.Amount * (percentconf.Percentage / CONVERT(DECIMAL(19,2), 100.00)), 2)
                )
            ) AS InvoiceScheduleLineTotal
        FROM JobGroupInvoiceSchedules AS jgis
        JOIN SFin.InvoiceSchedules AS sch
            ON sch.ID = jgis.InvoiceScheduleID
        JOIN SFin.InvoiceSchedulePercentageConfiguration AS percentconf
            ON percentconf.InvoiceScheduleId = sch.ID
        WHERE sch.RowStatus NOT IN (0,254)
          AND percentconf.RowStatus NOT IN (0,254)
        GROUP BY sch.ID
    ),
    InvoiceScheduleConfiguredTotals AS
    (
        SELECT
            isclt.InvoiceScheduleID,
            SUM(isclt.InvoiceScheduleLineTotal) AS InvoiceScheduleConfiguredTotal
        FROM InvoiceScheduleConfiguredLineTotals AS isclt
        GROUP BY isclt.InvoiceScheduleID
    ),
    InvoiceScheduleJobGroupTotals AS
    (
        SELECT
            jgis.JobGroupKey,
            SUM
            (
                CASE
                    WHEN isct.InvoiceScheduleConfiguredTotal IS NOT NULL THEN isct.InvoiceScheduleConfiguredTotal
                    ELSE CONVERT(DECIMAL(19,2), sch.Amount)
                END
            ) AS InvoiceScheduleJobGroupTotal
        FROM JobGroupInvoiceSchedules AS jgis
        JOIN SFin.InvoiceSchedules AS sch
            ON sch.ID = jgis.InvoiceScheduleID
        LEFT JOIN InvoiceScheduleConfiguredTotals AS isct
            ON isct.InvoiceScheduleID = sch.ID
        WHERE sch.RowStatus NOT IN (0,254)
        GROUP BY jgis.JobGroupKey
    ),
    QuoteStageTotals AS
    (
        SELECT
            jgqi.JobGroupKey,
            jgqi.InvoiceScheduleID,
            jgqi.QuoteItemStageID,
            SUM(jgqi.LineNet) AS QuoteItemStageTotal
        FROM JobGroupedQuoteItems AS jgqi
        WHERE jgqi.InvoiceScheduleID > 0
        GROUP BY
            jgqi.JobGroupKey,
            jgqi.InvoiceScheduleID,
            jgqi.QuoteItemStageID
    ),
    SelectedSchedules AS
    (
        SELECT DISTINCT
            jgqi.InvoiceScheduleID
        FROM JobGroupedQuoteItems AS jgqi
        WHERE jgqi.InvoiceScheduleID > 0
    ),
    ScheduleStageAmounts AS
    (
        SELECT
            sch.ID AS InvoiceScheduleID,
            monthconf.RIBAStageId AS QuoteItemStageID,
            SUM(CONVERT(DECIMAL(19,2), monthconf.Amount)) AS InvoiceScheduleStageTotal
        FROM SelectedSchedules AS ss
        JOIN SFin.InvoiceSchedules AS sch
            ON sch.ID = ss.InvoiceScheduleID
        JOIN SFin.InvoiceScheduleMonthConfiguration AS monthconf
            ON monthconf.InvoiceScheduleId = sch.ID
        WHERE sch.RowStatus NOT IN (0,254)
          AND monthconf.RowStatus NOT IN (0,254)
          AND monthconf.RIBAStageId > 0
        GROUP BY
            sch.ID,
            monthconf.RIBAStageId

        UNION ALL

        SELECT
            sch.ID AS InvoiceScheduleID,
            percentconf.RIBAStageId AS QuoteItemStageID,
            SUM
            (
                CONVERT
                (
                    DECIMAL(19,2),
                    ROUND(sch.Amount * (percentconf.Percentage / CONVERT(DECIMAL(19,2), 100.00)), 2)
                )
            ) AS InvoiceScheduleStageTotal
        FROM SelectedSchedules AS ss
        JOIN SFin.InvoiceSchedules AS sch
            ON sch.ID = ss.InvoiceScheduleID
        JOIN SFin.InvoiceSchedulePercentageConfiguration AS percentconf
            ON percentconf.InvoiceScheduleId = sch.ID
        WHERE sch.RowStatus NOT IN (0,254)
          AND percentconf.RowStatus NOT IN (0,254)
          AND percentconf.RIBAStageId > 0
        GROUP BY
            sch.ID,
            percentconf.RIBAStageId
    ),
    ScheduleStageTotals AS
    (
        SELECT
            ssa.InvoiceScheduleID,
            ssa.QuoteItemStageID,
            SUM(ssa.InvoiceScheduleStageTotal) AS InvoiceScheduleStageTotal
        FROM ScheduleStageAmounts AS ssa
        GROUP BY
            ssa.InvoiceScheduleID,
            ssa.QuoteItemStageID
    ),
    StageNames AS
    (
        SELECT
            rs.ID AS QuoteItemStageID,
            CASE
                WHEN rs.Number BETWEEN 0 AND 7
                    THEN N'RIBA Stage ' + CONVERT(NVARCHAR(20), rs.Number) + N' - ' + rs.Description
                ELSE N'Fee Stage ' + CONVERT(NVARCHAR(20), rs.Number) + N' - ' + rs.Description
            END AS StageName
        FROM SJob.RibaStages AS rs
        WHERE rs.RowStatus NOT IN (0,254)
    )
    INSERT INTO @Validation
    (
        SeverityCode,
        ValidationCode,
        QuoteItemStageID,
        InvoiceScheduleID,
        StageName,
        QuoteItemStageTotal,
        InvoiceScheduleStageTotal,
        Message
    )
    SELECT
        N'B',
        N'QuoteJobGroupInvoiceScheduleTotalMismatch',
        -1,
        -1,
        qjgt.JobGroupName,
        qjgt.QuoteItemJobGroupTotal,
        ISNULL(isjgt.InvoiceScheduleJobGroupTotal, CONVERT(DECIMAL(19,2), 0.00)),
        N'The total of the Invoice Schedule must be equal to the total of the Quote Item(s) before conversion to a Job.'
    FROM QuoteJobGroupTotals AS qjgt
    JOIN InvoiceScheduleJobGroupTotals AS isjgt
        ON isjgt.JobGroupKey = qjgt.JobGroupKey
    WHERE qjgt.QuoteItemJobGroupTotal <> isjgt.InvoiceScheduleJobGroupTotal;

    ;WITH EligibleQuoteItems AS
    (
        SELECT
            CONVERT(INT, qi.ID) AS QuoteItemID,
            qi.QuoteId,
            ISNULL(resolvedInvoiceSchedule.InvoiceScheduleID, -1) AS InvoiceScheduleID,
            CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END AS QuoteItemStageID,
            CONVERT(DECIMAL(19,2), qit.LineNet) AS LineNet,
            CASE WHEN prod.NeverConsolidate = 1 OR qi.DoNotConsolidateJob = 1 THEN CONVERT(BIT,1) ELSE CONVERT(BIT,0) END AS IsIndividualJob,
            CASE WHEN prod.CreatedJobType > 0 THEN prod.CreatedJobType ELSE es.JobTypeId END AS JobTypeID,
            ISNULL(jt.Name, N'Unknown Job Type') AS JobTypeName
        FROM SSop.QuoteItems AS qi
        JOIN SSop.QuoteItemTotals AS qit
            ON qit.ID = qi.ID
        JOIN SSop.Quotes AS q
            ON q.ID = qi.QuoteId
        JOIN SSop.EnquiryServices AS es
            ON es.ID = q.EnquiryServiceID
        JOIN SProd.Products AS prod
            ON prod.ID = qi.ProductId
        LEFT JOIN SJob.JobTypes AS jt
            ON jt.ID = CASE WHEN prod.CreatedJobType > 0 THEN prod.CreatedJobType ELSE es.JobTypeId END
        LEFT JOIN SSop.InvoiceSchedules AS quoteItemSchedule
            ON quoteItemSchedule.ID = qi.InvoicingSchedule
           AND quoteItemSchedule.RowStatus NOT IN (0,254)
        OUTER APPLY
        (
            SELECT TOP (1)
                invs.ID AS InvoiceScheduleID
            FROM SFin.InvoiceSchedules AS invs
            WHERE invs.QuoteId = q.ID
              AND invs.RowStatus NOT IN (0,254)
              AND ISNULL(qi.InvoicingSchedule, -1) > 0
              AND
              (
                     invs.ID = qi.InvoicingSchedule
                  OR
                     (
                         quoteItemSchedule.ID IS NOT NULL
                     AND LTRIM(RTRIM(invs.Name)) = LTRIM(RTRIM(quoteItemSchedule.Name))
                     )
              )
              AND
              (
                  EXISTS
                  (
                      SELECT 1
                      FROM SFin.InvoiceScheduleMonthConfiguration AS mc
                      WHERE mc.InvoiceScheduleId = invs.ID
                        AND mc.RowStatus NOT IN (0,254)
                  )
                  OR EXISTS
                  (
                      SELECT 1
                      FROM SFin.InvoiceSchedulePercentageConfiguration AS pc
                      WHERE pc.InvoiceScheduleId = invs.ID
                        AND pc.RowStatus NOT IN (0,254)
                  )
              )
            ORDER BY
                CASE
                    WHEN invs.ID = qi.InvoicingSchedule THEN 0
                    WHEN quoteItemSchedule.ID IS NOT NULL
                     AND LTRIM(RTRIM(invs.Name)) = LTRIM(RTRIM(quoteItemSchedule.Name)) THEN 1
                    ELSE 2
                END,
                invs.ID
        ) AS resolvedInvoiceSchedule
        WHERE qi.QuoteId = @QuoteID
          AND qi.RowStatus NOT IN (0,254)
          AND qi.Quantity > 0
          AND ISNULL(qi.CreatedJobId, -1) <= 0
          AND CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END > 0
    ),
    JobGroupedQuoteItems AS
    (
        SELECT
            eqi.QuoteItemID,
            eqi.InvoiceScheduleID,
            eqi.QuoteItemStageID,
            eqi.LineNet,
            CASE
                WHEN eqi.IsIndividualJob = 1 THEN N'QI:' + CONVERT(NVARCHAR(20), eqi.QuoteItemID)
                ELSE N'CON:' + CONVERT(NVARCHAR(20), eqi.JobTypeID)
            END AS JobGroupKey
        FROM EligibleQuoteItems AS eqi
    ),
    QuoteStageTotals AS
    (
        SELECT
            jgqi.JobGroupKey,
            jgqi.InvoiceScheduleID,
            jgqi.QuoteItemStageID,
            SUM(jgqi.LineNet) AS QuoteItemStageTotal
        FROM JobGroupedQuoteItems AS jgqi
        WHERE jgqi.InvoiceScheduleID > 0
        GROUP BY
            jgqi.JobGroupKey,
            jgqi.InvoiceScheduleID,
            jgqi.QuoteItemStageID
    ),
    SelectedSchedules AS
    (
        SELECT DISTINCT
            jgqi.InvoiceScheduleID
        FROM JobGroupedQuoteItems AS jgqi
        WHERE jgqi.InvoiceScheduleID > 0
    ),
    ScheduleStageAmounts AS
    (
        SELECT
            sch.ID AS InvoiceScheduleID,
            monthconf.RIBAStageId AS QuoteItemStageID,
            SUM(CONVERT(DECIMAL(19,2), monthconf.Amount)) AS InvoiceScheduleStageTotal
        FROM SelectedSchedules AS ss
        JOIN SFin.InvoiceSchedules AS sch
            ON sch.ID = ss.InvoiceScheduleID
        JOIN SFin.InvoiceScheduleMonthConfiguration AS monthconf
            ON monthconf.InvoiceScheduleId = sch.ID
        WHERE sch.RowStatus NOT IN (0,254)
          AND monthconf.RowStatus NOT IN (0,254)
          AND monthconf.RIBAStageId > 0
        GROUP BY
            sch.ID,
            monthconf.RIBAStageId

        UNION ALL

        SELECT
            sch.ID AS InvoiceScheduleID,
            percentconf.RIBAStageId AS QuoteItemStageID,
            SUM
            (
                CONVERT
                (
                    DECIMAL(19,2),
                    ROUND(sch.Amount * (percentconf.Percentage / CONVERT(DECIMAL(19,2), 100.00)), 2)
                )
            ) AS InvoiceScheduleStageTotal
        FROM SelectedSchedules AS ss
        JOIN SFin.InvoiceSchedules AS sch
            ON sch.ID = ss.InvoiceScheduleID
        JOIN SFin.InvoiceSchedulePercentageConfiguration AS percentconf
            ON percentconf.InvoiceScheduleId = sch.ID
        WHERE sch.RowStatus NOT IN (0,254)
          AND percentconf.RowStatus NOT IN (0,254)
          AND percentconf.RIBAStageId > 0
        GROUP BY
            sch.ID,
            percentconf.RIBAStageId
    ),
    ScheduleStageTotals AS
    (
        SELECT
            ssa.InvoiceScheduleID,
            ssa.QuoteItemStageID,
            SUM(ssa.InvoiceScheduleStageTotal) AS InvoiceScheduleStageTotal
        FROM ScheduleStageAmounts AS ssa
        GROUP BY
            ssa.InvoiceScheduleID,
            ssa.QuoteItemStageID
    ),
    StageNames AS
    (
        SELECT
            rs.ID AS QuoteItemStageID,
            CASE
                WHEN rs.Number BETWEEN 0 AND 7
                    THEN N'RIBA Stage ' + CONVERT(NVARCHAR(20), rs.Number) + N' - ' + rs.Description
                ELSE N'Fee Stage ' + CONVERT(NVARCHAR(20), rs.Number) + N' - ' + rs.Description
            END AS StageName
        FROM SJob.RibaStages AS rs
        WHERE rs.RowStatus NOT IN (0,254)
    )
    INSERT INTO @Validation
    (
        SeverityCode,
        ValidationCode,
        QuoteItemStageID,
        InvoiceScheduleID,
        StageName,
        QuoteItemStageTotal,
        InvoiceScheduleStageTotal,
        Message
    )
    SELECT
        N'W',
        N'QuoteItemStageMissingFromInvoiceSchedule',
        qst.QuoteItemStageID,
        qst.InvoiceScheduleID,
        ISNULL(sn.StageName, N'Stage ' + CONVERT(NVARCHAR(20), qst.QuoteItemStageID)),
        qst.QuoteItemStageTotal,
        NULL,
        N'The quote item stage is not in the Invoice schedule, do you want to continue?'
    FROM QuoteStageTotals AS qst
    LEFT JOIN ScheduleStageTotals AS sst
        ON sst.InvoiceScheduleID = qst.InvoiceScheduleID
       AND sst.QuoteItemStageID = qst.QuoteItemStageID
    LEFT JOIN StageNames AS sn
        ON sn.QuoteItemStageID = qst.QuoteItemStageID
    WHERE qst.InvoiceScheduleID > 0
      AND sst.InvoiceScheduleStageTotal IS NULL;

    RETURN;
END;
GO