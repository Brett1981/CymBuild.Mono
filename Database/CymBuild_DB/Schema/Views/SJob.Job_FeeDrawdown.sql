SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create view [SJob].[Job_FeeDrawdown]')
GO
/*
    CYB-339
    Makes the job fee grid stage-keyed where dynamic quote-item carry-over rows exist.

    Behaviour preserved:
    - Existing jobs without SJob.JobRibaStageFees continue to use SJob.Jobs fixed fee columns.
    - Existing FeeAmendment fixed-column adjustments continue to apply for standard numbered buckets.
    - Existing totals remain compatible, but new jobs with dynamic stage fee rows total from SJob.JobRibaStageFees.

    Behaviour added:
    - Any active RIBA stage row, including user-created stages, can show an agreed value by JobID + RibaStageID.
    - Paid displays as Net (Gross), for example 100.00 (120.00), apportioned from allocations against posted invoice transactions.
*/

CREATE   VIEW [SJob].[Job_FeeDrawdown]
AS
SELECT
    j.ID,
    j.RowStatus,
    j.Guid,
    CASE
        WHEN rs.Number = -1 THEN N'Fee Cap'
        ELSE CONVERT(NVARCHAR(10), rs.Number)
    END AS Stage,
    CASE
        WHEN rs.Number = -1 THEN N'Fee Cap'
        ELSE rs.Description
    END AS StageLabel,
    stage_calc.Agreed AS Agreed,
    ISNULL(invoiced.Invoiced, 0) AS Invoiced,
    CONVERT(NVARCHAR(50), CAST(ISNULL(paid.PaidNet, 0) AS DECIMAL(19, 2)))
        + N' (' + CONVERT(NVARCHAR(50), CAST(ISNULL(paid.PaidGross, 0) AS DECIMAL(19, 2))) + N')' AS Paid,
    stage_calc.Agreed - ISNULL(invoiced.Invoiced, 0) AS Remaining,
    ISNULL(quoted.NumberOfMeetings, 0) + stage_calc.MeetingAdjustment AS QuotedMeetings,
    ISNULL(completed.MeetingTotal, 0) AS CompletedMeetings,
    ISNULL(quoted.NumberOfSiteVisits, 0) + stage_calc.VisitAdjustment AS QuotedSiteVisits,
    ISNULL(completed.SiteVisitTotal, 0) AS CompletedSiteVisits,
    j.ID AS JobId,
    rs.ID AS StageId,
    CAST(0 AS BIT) AS IsTotalHighlightRow
FROM SJob.Jobs AS j
CROSS JOIN SJob.RibaStages AS rs
OUTER APPLY
(
    SELECT
        SUM(jrsf.AgreedFee) AS DynamicAgreedFee
    FROM SJob.JobRibaStageFees AS jrsf
    WHERE jrsf.JobID = j.ID
      AND jrsf.RibaStageID = rs.ID
      AND jrsf.RowStatus NOT IN (0,254)
) AS dynamic_stage
OUTER APPLY
(
    SELECT
        CASE WHEN EXISTS
        (
            SELECT 1
            FROM SJob.JobRibaStageFees AS jrsf_exists
            WHERE jrsf_exists.JobID = j.ID
              AND jrsf_exists.RowStatus NOT IN (0,254)
        ) THEN 1 ELSE 0 END AS HasDynamicStageFees
) AS dynamic_mode
OUTER APPLY
(
    SELECT
        SUM(cfa.StageChange) AS CustomFeeChange,
        SUM(cfa.StageMeetingChange) AS CustomMeetingChange,
        SUM(cfa.StageVisitChange) AS CustomVisitChange
    FROM SJob.CustomFeeAmendment cfa
    WHERE cfa.JobID = j.ID
      AND cfa.StageId = rs.ID
      AND cfa.RowStatus NOT IN (0,254)
) custom_amendments
OUTER APPLY
(
    SELECT
        SUM(fa.RibaStage0Change) AS Stage0Change,
        SUM(fa.RibaStage1Change) AS Stage1Change,
        SUM(fa.RibaStage2Change) AS Stage2Change,
        SUM(fa.RibaStage3Change) AS Stage3Change,
        SUM(fa.RibaStage4Change) AS Stage4Change,
        SUM(fa.RibaStage5Change) AS Stage5Change,
        SUM(fa.RibaStage6Change) AS Stage6Change,
        SUM(fa.RibaStage7Change) AS Stage7Change,
        SUM(fa.PreConstructionStageChange) AS PreConstructionStageChange,
        SUM(fa.ConstructionStageChange) AS ConstructionStageChange,
        SUM(fa.FeeCapChange) AS FeeCapChange,
        SUM(fa.RibaStage0MeetingChange) AS MeetingsStage0Change,
        SUM(fa.RibaStage1MeetingChange) AS MeetingsStage1Change,
        SUM(fa.RibaStage2MeetingChange) AS MeetingsStage2Change,
        SUM(fa.RibaStage3MeetingChange) AS MeetingsStage3Change,
        SUM(fa.RibaStage4MeetingChange) AS MeetingsStage4Change,
        SUM(fa.RibaStage5MeetingChange) AS MeetingsStage5Change,
        SUM(fa.RibaStage6MeetingChange) AS MeetingsStage6Change,
        SUM(fa.RibaStage7MeetingChange) AS MeetingsStage7Change,
        SUM(fa.PreConstructionStageMeetingChange) AS PreConstructionMeetingChange,
        SUM(fa.ConstructionStageMeetingChange) AS ConstructionMeetingChange,
        SUM(fa.RibaStage0VisitChange) AS VisitStage0Change,
        SUM(fa.RibaStage1VisitChange) AS VisitStage1Change,
        SUM(fa.RibaStage2VisitChange) AS VisitStage2Change,
        SUM(fa.RibaStage3VisitChange) AS VisitStage3Change,
        SUM(fa.RibaStage4VisitChange) AS VisitStage4Change,
        SUM(fa.RibaStage5VisitChange) AS VisitStage5Change,
        SUM(fa.RibaStage6VisitChange) AS VisitStage6Change,
        SUM(fa.RibaStage7VisitChange) AS VisitStage7Change,
        SUM(fa.PreConstructionStageVisitChange) AS PreConstructionVisitChange,
        SUM(fa.ConstructionStageVisitChange) AS ConstructionVisitChange
    FROM SJob.FeeAmendment AS fa
    WHERE fa.JobId = j.ID
      AND fa.RowStatus NOT IN (0,254)
) AS amendments
OUTER APPLY
(
    SELECT
        SUM(x.FeeChange) AS DynamicFeeChange,
        SUM(x.MeetingChange) AS DynamicMeetingChange,
        SUM(x.VisitChange) AS DynamicVisitChange
    FROM
    (
        SELECT
            fars.FeeChange,
            fars.MeetingChange,
            fars.VisitChange
        FROM SJob.FeeAmendmentRibaStages fars
        WHERE fars.JobID = j.ID
          AND fars.RibaStageID = rs.ID
          AND fars.RowStatus NOT IN (0,254)

        UNION ALL

        SELECT
            cfa.StageChange,
            cfa.StageMeetingChange,
            cfa.StageVisitChange
        FROM SJob.CustomFeeAmendment cfa
        WHERE cfa.JobID = j.ID
          AND cfa.StageId = rs.ID
          AND cfa.RowStatus NOT IN (0,254)
    ) x
) AS dynamic_amendments
OUTER APPLY
(
    SELECT
        CASE rs.Number
            WHEN 0 THEN 0
            WHEN 1 THEN j.RibaStage1Fee
            WHEN 2 THEN j.RibaStage2Fee
            WHEN 3 THEN j.RibaStage3Fee
            WHEN 4 THEN j.RibaStage4Fee
            WHEN 5 THEN j.RibaStage5Fee
            WHEN 6 THEN j.RibaStage6Fee
            WHEN 7 THEN j.RibaStage7Fee
            WHEN 99 THEN j.PreConstructionStageFee
            WHEN 999 THEN j.ConstructionStageFee
            WHEN -1 THEN j.FeeCap
            ELSE 0
        END AS LegacyAgreedFee,
        CASE rs.Number
            WHEN 0 THEN ISNULL(amendments.Stage0Change, 0)
            WHEN 1 THEN ISNULL(amendments.Stage1Change, 0)
            WHEN 2 THEN ISNULL(amendments.Stage2Change, 0)
            WHEN 3 THEN ISNULL(amendments.Stage3Change, 0)
            WHEN 4 THEN ISNULL(amendments.Stage4Change, 0)
            WHEN 5 THEN ISNULL(amendments.Stage5Change, 0)
            WHEN 6 THEN ISNULL(amendments.Stage6Change, 0)
            WHEN 7 THEN ISNULL(amendments.Stage7Change, 0)
            WHEN 99 THEN ISNULL(amendments.PreConstructionStageChange, 0)
            WHEN 999 THEN ISNULL(amendments.ConstructionStageChange, 0)
            WHEN -1 THEN ISNULL(amendments.FeeCapChange, 0)
            ELSE 0
        END AS FeeAdjustment,
        CASE rs.Number
            WHEN 0 THEN ISNULL(amendments.MeetingsStage0Change, 0)
            WHEN 1 THEN ISNULL(amendments.MeetingsStage1Change, 0)
            WHEN 2 THEN ISNULL(amendments.MeetingsStage2Change, 0)
            WHEN 3 THEN ISNULL(amendments.MeetingsStage3Change, 0)
            WHEN 4 THEN ISNULL(amendments.MeetingsStage4Change, 0)
            WHEN 5 THEN ISNULL(amendments.MeetingsStage5Change, 0)
            WHEN 6 THEN ISNULL(amendments.MeetingsStage6Change, 0)
            WHEN 7 THEN ISNULL(amendments.MeetingsStage7Change, 0)
            WHEN 99 THEN ISNULL(amendments.PreConstructionMeetingChange, 0)
            WHEN 999 THEN ISNULL(amendments.ConstructionMeetingChange, 0)
            ELSE 0
        END AS MeetingAdjustment,
        CASE rs.Number
            WHEN 0 THEN ISNULL(amendments.VisitStage0Change, 0)
            WHEN 1 THEN ISNULL(amendments.VisitStage1Change, 0)
            WHEN 2 THEN ISNULL(amendments.VisitStage2Change, 0)
            WHEN 3 THEN ISNULL(amendments.VisitStage3Change, 0)
            WHEN 4 THEN ISNULL(amendments.VisitStage4Change, 0)
            WHEN 5 THEN ISNULL(amendments.VisitStage5Change, 0)
            WHEN 6 THEN ISNULL(amendments.VisitStage6Change, 0)
            WHEN 7 THEN ISNULL(amendments.VisitStage7Change, 0)
            WHEN 99 THEN ISNULL(amendments.PreConstructionVisitChange, 0)
            WHEN 999 THEN ISNULL(amendments.ConstructionVisitChange, 0)
            ELSE 0
        END AS VisitAdjustment
) AS stage_parts
OUTER APPLY
(
    SELECT
        CASE
            WHEN dynamic_mode.HasDynamicStageFees = 1 AND rs.Number <> -1
                THEN ISNULL(dynamic_stage.DynamicAgreedFee, 0)
                     + stage_parts.FeeAdjustment
                     + ISNULL(dynamic_amendments.DynamicFeeChange, 0)
            ELSE stage_parts.LegacyAgreedFee
                 + stage_parts.FeeAdjustment
                 + ISNULL(dynamic_amendments.DynamicFeeChange, 0)
        END AS Agreed,
        stage_parts.MeetingAdjustment + ISNULL(dynamic_amendments.DynamicMeetingChange, 0) AS MeetingAdjustment,
        stage_parts.VisitAdjustment + ISNULL(dynamic_amendments.DynamicVisitChange, 0) AS VisitAdjustment
) AS stage_calc
OUTER APPLY
(
    SELECT
        CAST(
            SUM(td.Net * CASE WHEN tt.IsNegated = 1 THEN -1 ELSE 1 END)
            AS DECIMAL(19, 2)
        ) AS Invoiced
    FROM SFin.TransactionDetails AS td
    JOIN SFin.Transactions AS t
        ON t.ID = td.TransactionID
       AND t.JobID = j.ID
       AND t.RowStatus NOT IN (0,254)
       AND ISNULL(t.Batched, 0) = 0
    JOIN SFin.TransactionTypes AS tt
        ON tt.ID = t.TransactionTypeID
       AND tt.RowStatus NOT IN (0,254)
       AND tt.IsBank = 0
    LEFT JOIN SJob.Activities AS a
        ON a.ID = td.ActivityID
       AND a.JobId = j.ID
       AND a.RowStatus NOT IN (0,254)
    LEFT JOIN SFin.InvoiceRequestItems AS iri
        ON iri.ID = td.InvoiceRequestItemId
       AND iri.RowStatus NOT IN (0,254)
    WHERE td.RowStatus NOT IN (0,254)
      AND
      (
             td.RIBAStageID = rs.ID
          OR a.RibaStageId = rs.ID
          OR iri.RIBAStageId = rs.ID
      )
) AS invoiced
OUTER APPLY
(
    SELECT
        CAST(
            SUM(
                CASE
                    WHEN ISNULL(tx_gross.TransactionGross, 0) = 0 THEN 0
                    ELSE ta.AllocatedAmount * (td.Net / tx_gross.TransactionGross)
                END
            ) AS DECIMAL(19, 2)
        ) AS PaidNet,
        CAST(
            SUM(
                CASE
                    WHEN ISNULL(tx_gross.TransactionGross, 0) = 0 THEN 0
                    ELSE ta.AllocatedAmount * (td.Gross / tx_gross.TransactionGross)
                END
            ) AS DECIMAL(19, 2)
        ) AS PaidGross
    FROM SFin.TransactionDetails AS td
    JOIN SFin.Transactions AS t
        ON t.ID = td.TransactionID
       AND t.JobID = j.ID
       AND t.RowStatus NOT IN (0,254)
       AND ISNULL(t.Batched, 0) = 0
    JOIN SFin.TransactionTypes AS tt
        ON tt.ID = t.TransactionTypeID
       AND tt.RowStatus NOT IN (0,254)
       AND tt.IsBank = 0
    JOIN SFin.TransactionAllocations AS ta
        ON ta.TargetTransactionID = t.ID
       AND ta.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT
            CAST(SUM(ISNULL(td2.Gross, 0)) AS DECIMAL(19, 2)) AS TransactionGross
        FROM SFin.TransactionDetails AS td2
        WHERE td2.TransactionID = t.ID
          AND td2.RowStatus NOT IN (0,254)
    ) AS tx_gross
    LEFT JOIN SJob.Activities AS a
        ON a.ID = td.ActivityID
       AND a.JobId = j.ID
       AND a.RowStatus NOT IN (0,254)
    LEFT JOIN SFin.InvoiceRequestItems AS iri
        ON iri.ID = td.InvoiceRequestItemId
       AND iri.RowStatus NOT IN (0,254)
    WHERE td.RowStatus NOT IN (0,254)
      AND
      (
             td.RIBAStageID = rs.ID
          OR a.RibaStageId = rs.ID
          OR iri.RIBAStageId = rs.ID
      )
) AS paid
OUTER APPLY
(
    SELECT
        SUM(qi.NumberOfMeetings) AS NumberOfMeetings,
        SUM(qi.NumberOfSiteVisits) AS NumberOfSiteVisits
    FROM SSop.QuoteItems AS qi
    WHERE qi.CreatedJobId = j.ID
      AND CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END = rs.ID
      AND qi.RowStatus NOT IN (0,254)
) AS quoted
OUTER APPLY
(
    SELECT
        SUM(CASE WHEN jat.IsMeeting = 1 THEN 1 ELSE 0 END) AS MeetingTotal,
        SUM(CASE WHEN jat.IsSiteVisit = 1 THEN 1 ELSE 0 END) AS SiteVisitTotal
    FROM SJob.Activities AS ja
    JOIN SJob.ActivityTypes AS jat
        ON jat.ID = ja.ActivityTypeID
    JOIN SJob.ActivityStatus AS jas
        ON jas.ID = ja.ActivityStatusID
    WHERE ja.JobId = j.ID
      AND ja.RibaStageId = rs.ID
      AND jas.Name = N'Complete'
      AND ja.RowStatus NOT IN (0,254)
      AND (jat.IsMeeting = 1 OR jat.IsSiteVisit = 1)
) AS completed
WHERE j.RowStatus NOT IN (0,254)
  AND rs.ID > 0
  AND rs.RowStatus NOT IN (0,254)
  AND
  (
        (rs.IsRealStage = 1 AND ((j.PreConstructionStageFee = 0 AND j.ConstructionStageFee = 0) OR dynamic_mode.HasDynamicStageFees = 1))
     OR (rs.IsRealStage = 0 AND ((j.PreConstructionStageFee <> 0 OR j.ConstructionStageFee <> 0) OR dynamic_stage.DynamicAgreedFee IS NOT NULL))
  )
UNION ALL
SELECT
    j.ID,
    j.RowStatus,
    j.Guid,
    N'Total (ex. Fee Cap.)' AS Stage,
    N'Total (ex. Fee Cap.)' AS StageLabel,
    totals.TotalExFeeCap AS Agreed,
    ISNULL(invoiced_totals.InvoicedNet, 0) AS Invoiced,
    CONVERT(NVARCHAR(50), CAST(ISNULL(paid_totals.PaidNet, 0) AS DECIMAL(19, 2)))
        + N' (' + CONVERT(NVARCHAR(50), CAST(ISNULL(paid_totals.PaidGross, 0) AS DECIMAL(19, 2))) + N')' AS Paid,
    totals.TotalExFeeCap - ISNULL(invoiced_totals.InvoicedNet, 0) AS Remaining,
    ISNULL(quoted_totals.Meetings, 0) + ISNULL(amendment_totals.TotalMeetingChange, 0) AS QuotedMeetings,
    ISNULL(completed_totals.MeetingTotal, 0) AS CompletedMeetings,
    ISNULL(quoted_totals.SiteVisits, 0) + ISNULL(amendment_totals.TotalVisitChange, 0) AS QuotedSiteVisits,
    ISNULL(completed_totals.SiteVisitTotal, 0) AS CompletedSiteVisits,
    j.ID AS JobId,
    -2 AS StageId,
    CAST(1 AS BIT) AS IsTotalHighlightRow
FROM SJob.Jobs AS j
LEFT JOIN SJob.JobFinance AS jf
    ON jf.ID = j.ID
OUTER APPLY
(
    SELECT
        SUM(jrsf.AgreedFee) AS DynamicTotal
    FROM SJob.JobRibaStageFees AS jrsf
    WHERE jrsf.JobID = j.ID
      AND jrsf.RowStatus NOT IN (0,254)
) AS dynamic_totals
OUTER APPLY
(
    SELECT
        SUM(x.FeeChange) AS TotalChange,
        SUM(x.MeetingChange) AS TotalMeetingChange,
        SUM(x.VisitChange) AS TotalVisitChange
    FROM
    (
        SELECT
            fa.RibaStage0Change + fa.RibaStage1Change + fa.RibaStage2Change + fa.RibaStage3Change +
            fa.RibaStage4Change + fa.RibaStage5Change + fa.RibaStage6Change + fa.RibaStage7Change +
            fa.PreConstructionStageChange + fa.ConstructionStageChange AS FeeChange,

            fa.RibaStage0MeetingChange + fa.RibaStage1MeetingChange + fa.RibaStage2MeetingChange +
            fa.RibaStage3MeetingChange + fa.RibaStage4MeetingChange + fa.RibaStage5MeetingChange +
            fa.RibaStage6MeetingChange + fa.RibaStage7MeetingChange +
            fa.PreConstructionStageMeetingChange + fa.ConstructionStageMeetingChange AS MeetingChange,

            fa.RibaStage0VisitChange + fa.RibaStage1VisitChange + fa.RibaStage2VisitChange +
            fa.RibaStage3VisitChange + fa.RibaStage4VisitChange + fa.RibaStage5VisitChange +
            fa.RibaStage6VisitChange + fa.RibaStage7VisitChange +
            fa.PreConstructionStageVisitChange + fa.ConstructionStageVisitChange AS VisitChange
        FROM SJob.FeeAmendment fa
        WHERE fa.JobId = j.ID
          AND fa.RowStatus NOT IN (0,254)

        UNION ALL

        SELECT
            cfa.StageChange,
            cfa.StageMeetingChange,
            cfa.StageVisitChange
        FROM SJob.CustomFeeAmendment cfa
        WHERE cfa.JobId = j.ID
          AND cfa.RowStatus NOT IN (0,254)
    ) x
) AS amendment_totals
OUTER APPLY
(
    SELECT
        CASE
            WHEN dynamic_totals.DynamicTotal IS NOT NULL
                THEN dynamic_totals.DynamicTotal
            ELSE j.AgreedFee + j.PreConstructionStageFee + j.ConstructionStageFee
               + j.RibaStage1Fee + j.RibaStage2Fee + j.RibaStage3Fee + j.RibaStage4Fee
               + j.RibaStage5Fee + j.RibaStage6Fee + j.RibaStage7Fee
        END + ISNULL(amendment_totals.TotalChange, 0) AS TotalExFeeCap
) AS totals
OUTER APPLY
(
    SELECT
        CAST(
            SUM(td.Net * CASE WHEN tt.IsNegated = 1 THEN -1 ELSE 1 END)
            AS DECIMAL(19, 2)
        ) AS InvoicedNet
    FROM SFin.TransactionDetails AS td
    JOIN SFin.Transactions AS t
        ON t.ID = td.TransactionID
       AND t.JobID = j.ID
       AND t.RowStatus NOT IN (0,254)
       AND ISNULL(t.Batched, 0) = 0
    JOIN SFin.TransactionTypes AS tt
        ON tt.ID = t.TransactionTypeID
       AND tt.RowStatus NOT IN (0,254)
       AND tt.IsBank = 0
    WHERE td.RowStatus NOT IN (0,254)
) AS invoiced_totals
OUTER APPLY
(
    SELECT
        CAST(
            SUM(
                CASE
                    WHEN ISNULL(tx_gross.TransactionGross, 0) = 0 THEN 0
                    ELSE ta.AllocatedAmount * (td.Net / tx_gross.TransactionGross)
                END
            ) AS DECIMAL(19, 2)
        ) AS PaidNet,
        CAST(
            SUM(
                CASE
                    WHEN ISNULL(tx_gross.TransactionGross, 0) = 0 THEN 0
                    ELSE ta.AllocatedAmount * (td.Gross / tx_gross.TransactionGross)
                END
            ) AS DECIMAL(19, 2)
        ) AS PaidGross
    FROM SFin.TransactionDetails AS td
    JOIN SFin.Transactions AS t
        ON t.ID = td.TransactionID
       AND t.JobID = j.ID
       AND t.RowStatus NOT IN (0,254)
       AND ISNULL(t.Batched, 0) = 0
    JOIN SFin.TransactionTypes AS tt
        ON tt.ID = t.TransactionTypeID
       AND tt.RowStatus NOT IN (0,254)
       AND tt.IsBank = 0
    JOIN SFin.TransactionAllocations AS ta
        ON ta.TargetTransactionID = t.ID
       AND ta.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT
            CAST(SUM(ISNULL(td2.Gross, 0)) AS DECIMAL(19, 2)) AS TransactionGross
        FROM SFin.TransactionDetails AS td2
        WHERE td2.TransactionID = t.ID
          AND td2.RowStatus NOT IN (0,254)
    ) AS tx_gross
    WHERE td.RowStatus NOT IN (0,254)
) AS paid_totals
OUTER APPLY
(
    SELECT
        SUM(CASE WHEN jat.IsMeeting = 1 THEN 1 ELSE 0 END) AS MeetingTotal,
        SUM(CASE WHEN jat.IsSiteVisit = 1 THEN 1 ELSE 0 END) AS SiteVisitTotal
    FROM SJob.Activities AS ja
    JOIN SJob.ActivityTypes AS jat
        ON jat.ID = ja.ActivityTypeID
    JOIN SJob.ActivityStatus AS jas
        ON jas.ID = ja.ActivityStatusID
    WHERE ja.JobId = j.ID
      AND jas.Name = N'Complete'
      AND ja.RowStatus NOT IN (0,254)
      AND (jat.IsMeeting = 1 OR jat.IsSiteVisit = 1)
) AS completed_totals
OUTER APPLY
(
    SELECT
        SUM(qi.NumberOfMeetings) AS Meetings,
        SUM(qi.NumberOfSiteVisits) AS SiteVisits
    FROM SSop.QuoteItems AS qi
    WHERE qi.CreatedJobId = j.ID
      AND qi.RowStatus NOT IN (0,254)
) AS quoted_totals
WHERE j.RowStatus NOT IN (0,254)
UNION ALL
SELECT
    j.ID,
    j.RowStatus,
    j.Guid,
    N'Total (inc. Fee Cap)' AS Stage,
    N'Total (inc. Fee Cap)' AS StageLabel,
    totals.TotalIncFeeCap AS Agreed,
    ISNULL(invoiced_totals.InvoicedNet, 0) AS Invoiced,
    CONVERT(NVARCHAR(50), CAST(ISNULL(paid_totals.PaidNet, 0) AS DECIMAL(19, 2)))
        + N' (' + CONVERT(NVARCHAR(50), CAST(ISNULL(paid_totals.PaidGross, 0) AS DECIMAL(19, 2))) + N')' AS Paid,
    totals.TotalIncFeeCap - ISNULL(invoiced_totals.InvoicedNet, 0) AS Remaining,
    ISNULL(quoted_totals.Meetings, 0) + ISNULL(amendment_totals.TotalMeetingChange, 0) AS QuotedMeetings,
    ISNULL(completed_totals.MeetingTotal, 0) AS CompletedMeetings,
    ISNULL(quoted_totals.SiteVisits, 0) + ISNULL(amendment_totals.TotalVisitChange, 0) AS QuotedSiteVisits,
    ISNULL(completed_totals.SiteVisitTotal, 0) AS CompletedSiteVisits,
    j.ID AS JobId,
    -3 AS StageId,
    CAST(1 AS BIT) AS IsTotalHighlightRow
FROM SJob.Jobs AS j
LEFT JOIN SJob.JobFinance AS jf
    ON jf.ID = j.ID
OUTER APPLY
(
    SELECT
        SUM(jrsf.AgreedFee) AS DynamicTotal
    FROM SJob.JobRibaStageFees AS jrsf
    WHERE jrsf.JobID = j.ID
      AND jrsf.RowStatus NOT IN (0,254)
) AS dynamic_totals
OUTER APPLY
(
    SELECT
        SUM(x.FeeChange) AS TotalChange,
        SUM(x.MeetingChange) AS TotalMeetingChange,
        SUM(x.VisitChange) AS TotalVisitChange
    FROM
    (
        SELECT
            fa.RibaStage0Change + fa.RibaStage1Change + fa.RibaStage2Change + fa.RibaStage3Change +
            fa.RibaStage4Change + fa.RibaStage5Change + fa.RibaStage6Change + fa.RibaStage7Change +
            fa.PreConstructionStageChange + fa.ConstructionStageChange + fa.FeeCapChange AS FeeChange,

            fa.RibaStage0MeetingChange + fa.RibaStage1MeetingChange + fa.RibaStage2MeetingChange +
            fa.RibaStage3MeetingChange + fa.RibaStage4MeetingChange + fa.RibaStage5MeetingChange +
            fa.RibaStage6MeetingChange + fa.RibaStage7MeetingChange +
            fa.PreConstructionStageMeetingChange + fa.ConstructionStageMeetingChange AS MeetingChange,

            fa.RibaStage0VisitChange + fa.RibaStage1VisitChange + fa.RibaStage2VisitChange +
            fa.RibaStage3VisitChange + fa.RibaStage4VisitChange + fa.RibaStage5VisitChange +
            fa.RibaStage6VisitChange + fa.RibaStage7VisitChange +
            fa.PreConstructionStageVisitChange + fa.ConstructionStageVisitChange AS VisitChange
        FROM SJob.FeeAmendment fa
        WHERE fa.JobId = j.ID
          AND fa.RowStatus NOT IN (0,254)

        UNION ALL

        SELECT
            cfa.StageChange,
            cfa.StageMeetingChange,
            cfa.StageVisitChange
        FROM SJob.CustomFeeAmendment cfa
        WHERE cfa.JobId = j.ID
          AND cfa.RowStatus NOT IN (0,254)
    ) x
) AS amendment_totals
OUTER APPLY
(
    SELECT
        CASE
            WHEN dynamic_totals.DynamicTotal IS NOT NULL
                THEN dynamic_totals.DynamicTotal
            ELSE j.AgreedFee + j.PreConstructionStageFee + j.ConstructionStageFee
               + j.RibaStage1Fee + j.RibaStage2Fee + j.RibaStage3Fee + j.RibaStage4Fee
               + j.RibaStage5Fee + j.RibaStage6Fee + j.RibaStage7Fee
        END + j.FeeCap + ISNULL(amendment_totals.TotalChange, 0) AS TotalIncFeeCap
) AS totals
OUTER APPLY
(
    SELECT
        CAST(
            SUM(td.Net * CASE WHEN tt.IsNegated = 1 THEN -1 ELSE 1 END)
            AS DECIMAL(19, 2)
        ) AS InvoicedNet
    FROM SFin.TransactionDetails AS td
    JOIN SFin.Transactions AS t
        ON t.ID = td.TransactionID
       AND t.JobID = j.ID
       AND t.RowStatus NOT IN (0,254)
       AND ISNULL(t.Batched, 0) = 0
    JOIN SFin.TransactionTypes AS tt
        ON tt.ID = t.TransactionTypeID
       AND tt.RowStatus NOT IN (0,254)
       AND tt.IsBank = 0
    WHERE td.RowStatus NOT IN (0,254)
) AS invoiced_totals
OUTER APPLY
(
    SELECT
        CAST(
            SUM(
                CASE
                    WHEN ISNULL(tx_gross.TransactionGross, 0) = 0 THEN 0
                    ELSE ta.AllocatedAmount * (td.Net / tx_gross.TransactionGross)
                END
            ) AS DECIMAL(19, 2)
        ) AS PaidNet,
        CAST(
            SUM(
                CASE
                    WHEN ISNULL(tx_gross.TransactionGross, 0) = 0 THEN 0
                    ELSE ta.AllocatedAmount * (td.Gross / tx_gross.TransactionGross)
                END
            ) AS DECIMAL(19, 2)
        ) AS PaidGross
    FROM SFin.TransactionDetails AS td
    JOIN SFin.Transactions AS t
        ON t.ID = td.TransactionID
       AND t.JobID = j.ID
       AND t.RowStatus NOT IN (0,254)
       AND ISNULL(t.Batched, 0) = 0
    JOIN SFin.TransactionTypes AS tt
        ON tt.ID = t.TransactionTypeID
       AND tt.RowStatus NOT IN (0,254)
       AND tt.IsBank = 0
    JOIN SFin.TransactionAllocations AS ta
        ON ta.TargetTransactionID = t.ID
       AND ta.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT
            CAST(SUM(ISNULL(td2.Gross, 0)) AS DECIMAL(19, 2)) AS TransactionGross
        FROM SFin.TransactionDetails AS td2
        WHERE td2.TransactionID = t.ID
          AND td2.RowStatus NOT IN (0,254)
    ) AS tx_gross
    WHERE td.RowStatus NOT IN (0,254)
) AS paid_totals
OUTER APPLY
(
    SELECT
        SUM(CASE WHEN jat.IsMeeting = 1 THEN 1 ELSE 0 END) AS MeetingTotal,
        SUM(CASE WHEN jat.IsSiteVisit = 1 THEN 1 ELSE 0 END) AS SiteVisitTotal
    FROM SJob.Activities AS ja
    JOIN SJob.ActivityTypes AS jat
        ON jat.ID = ja.ActivityTypeID
    JOIN SJob.ActivityStatus AS jas
        ON jas.ID = ja.ActivityStatusID
    WHERE ja.JobId = j.ID
      AND jas.Name = N'Complete'
      AND ja.RowStatus NOT IN (0,254)
      AND (jat.IsMeeting = 1 OR jat.IsSiteVisit = 1)
) AS completed_totals
OUTER APPLY
(
    SELECT
        SUM(qi.NumberOfMeetings) AS Meetings,
        SUM(qi.NumberOfSiteVisits) AS SiteVisits
    FROM SSop.QuoteItems AS qi
    WHERE qi.CreatedJobId = j.ID
      AND qi.RowStatus NOT IN (0,254)
) AS quoted_totals
WHERE j.RowStatus NOT IN (0,254);

GO