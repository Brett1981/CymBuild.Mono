SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SJob].[Job_FeeDrawdown]
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
    CASE rs.Number
        WHEN N'0' THEN 0 + ISNULL(Amendments.Stage0Change, 0)
        WHEN N'1' THEN j.RibaStage1Fee + ISNULL(Amendments.Stage1Change, 0)
        WHEN N'2' THEN j.RibaStage2Fee + ISNULL(Amendments.Stage2Change, 0)
        WHEN N'3' THEN j.RibaStage3Fee + ISNULL(Amendments.Stage3Change, 0)
        WHEN N'4' THEN j.RibaStage4Fee + ISNULL(Amendments.Stage4Change, 0)
        WHEN N'5' THEN j.RibaStage5Fee + ISNULL(Amendments.Stage5Change, 0)
        WHEN N'6' THEN j.RibaStage6Fee + ISNULL(Amendments.Stage6Change, 0)
        WHEN N'7' THEN j.RibaStage7Fee + ISNULL(Amendments.Stage7Change, 0)
        WHEN N'99' THEN j.PreConstructionStageFee + ISNULL(Amendments.PreConstructionStageChange, 0)
        WHEN N'999' THEN j.ConstructionStageFee + ISNULL(Amendments.ConstructionStageChange, 0)
        ELSE j.FeeCap + ISNULL(Amendments.FeeCapChange, 0)
    END AS Agreed,

    -- Aggregated invoiced amount per stage:
    ISNULL(td_agg.TotalNet, 0) AS Invoiced,

    -- Remaining amount = agreed - invoiced
    CASE rs.Number
        WHEN N'0' THEN ISNULL(td_agg.TotalNet, 0)
        WHEN N'1' THEN j.RibaStage1Fee + ISNULL(Amendments.Stage1Change, 0)
        WHEN N'2' THEN j.RibaStage2Fee + ISNULL(Amendments.Stage2Change, 0)
        WHEN N'3' THEN j.RibaStage3Fee + ISNULL(Amendments.Stage3Change, 0)
        WHEN N'4' THEN j.RibaStage4Fee + ISNULL(Amendments.Stage4Change, 0)
        WHEN N'5' THEN j.RibaStage5Fee + ISNULL(Amendments.Stage5Change, 0)
        WHEN N'6' THEN j.RibaStage6Fee + ISNULL(Amendments.Stage6Change, 0)
        WHEN N'7' THEN j.RibaStage7Fee + ISNULL(Amendments.Stage7Change, 0)
        WHEN N'99' THEN j.PreConstructionStageFee + ISNULL(Amendments.PreConstructionStageChange, 0)
        WHEN N'999' THEN j.ConstructionStageFee + ISNULL(Amendments.ConstructionStageChange, 0)
        ELSE j.FeeCap
    END - ISNULL(td_agg.TotalNet, 0) AS Remaining,

    -- Quoted Meetings with amendments
    ISNULL(qi_agg.NumberOfMeetings, 0) + CASE rs.Number
        WHEN N'0' THEN ISNULL(Amendments.MeetingsStage0Change, 0)
        WHEN N'1' THEN ISNULL(Amendments.MeetingsStage1Change, 0)
        WHEN N'2' THEN ISNULL(Amendments.MeetingsStage2Change, 0)
        WHEN N'3' THEN ISNULL(Amendments.MeetingsStage3Change, 0)
        WHEN N'4' THEN ISNULL(Amendments.MeetingsStage4Change, 0)
        WHEN N'5' THEN ISNULL(Amendments.MeetingsStage5Change, 0)
        WHEN N'6' THEN ISNULL(Amendments.MeetingsStage6Change, 0)
        WHEN N'7' THEN ISNULL(Amendments.MeetingsStage7Change, 0)
        WHEN N'99' THEN ISNULL(Amendments.PreConstructionMeetingChange, 0)
        WHEN N'999' THEN ISNULL(Amendments.ConstructionMeetingChange, 0)
        ELSE 0
    END AS QuotedMeetings,

    -- Completed Meetings
    ISNULL(Meetings.MeetingTotal, 0) AS CompletedMeetings,

    -- Quoted Site Visits with amendments
    ISNULL(qi_agg.NumberOfSiteVisits, 0) + CASE rs.Number
        WHEN N'0' THEN ISNULL(Amendments.VisitStage0Change, 0)
        WHEN N'1' THEN ISNULL(Amendments.VisitStage1Change, 0)
        WHEN N'2' THEN ISNULL(Amendments.VisitStage2Change, 0)
        WHEN N'3' THEN ISNULL(Amendments.VisitStage3Change, 0)
        WHEN N'4' THEN ISNULL(Amendments.VisitStage4Change, 0)
        WHEN N'5' THEN ISNULL(Amendments.VisitStage5Change, 0)
        WHEN N'6' THEN ISNULL(Amendments.VisitStage6Change, 0)
        WHEN N'7' THEN ISNULL(Amendments.VisitStage7Change, 0)
        WHEN N'99' THEN ISNULL(Amendments.PreConstructionVisitChange, 0)
        WHEN N'999' THEN ISNULL(Amendments.ConstructionVisitChange, 0)
        ELSE 0
    END AS QuotedSiteVisits,

    -- Completed Site Visits
    ISNULL(Meetings.SiteVisitTotal, 0) AS CompletedSiteVisits,

    j.ID AS JobId,
    rs.ID AS StageId,
    0 AS IsTotalHighlightRow

FROM SJob.Jobs AS j
CROSS JOIN SJob.RibaStages AS rs

LEFT JOIN SJob.Activities AS a
    ON a.RibaStageId = rs.ID
    AND a.JobId = j.ID
    AND a.RowStatus NOT IN (0, 254)

-- Aggregate invoiced amount for the stage
OUTER APPLY (
    SELECT SUM(td.Net * CASE WHEN tt.IsNegated = 1 THEN -1 ELSE 1 END) AS TotalNet
    FROM SFin.TransactionDetails AS td
    JOIN SFin.Transactions AS t ON t.ID = td.TransactionID
    JOIN SFin.TransactionTypes AS tt ON tt.ID = t.TransactionTypeID
    WHERE (td.ActivityID = a.ID OR td.RIBAStageId = rs.ID)
		AND t.JobID = j.ID
        AND tt.IsBank = 0
        AND td.RowStatus NOT IN (0, 254)
        AND t.RowStatus NOT IN (0, 254)
) AS td_agg

-- Aggregate quote items per stage
OUTER APPLY (
    SELECT 
        SUM(qi.NumberOfMeetings) AS NumberOfMeetings,
        SUM(qi.NumberOfSiteVisits) AS NumberOfSiteVisits
    FROM SSop.QuoteItems AS qi
    WHERE qi.CreatedJobId = j.ID
        AND qi.ProvideAtStageID = rs.ID
        AND qi.RowStatus NOT IN (0, 254)
) AS qi_agg

-- Aggregate completed meetings and site visits per stage
OUTER APPLY (
    SELECT 
        SUM(CASE WHEN jat.IsMeeting = 1 THEN 1 ELSE 0 END) AS MeetingTotal,
        SUM(CASE WHEN jat.IsSiteVisit = 1 THEN 1 ELSE 0 END) AS SiteVisitTotal
    FROM SJob.Activities AS ja
    JOIN SJob.ActivityTypes AS jat ON jat.ID = ja.ActivityTypeID
    JOIN SJob.ActivityStatus AS jas ON jas.ID = ja.ActivityStatusID
    WHERE ja.JobId = j.ID
        AND jas.Name = N'Complete'
        AND ja.RowStatus NOT IN (0, 254)
        AND (jat.IsMeeting = 1 OR jat.IsSiteVisit = 1)
        AND ja.RibaStageId = rs.ID
) AS Meetings

OUTER APPLY (
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
    WHERE fa.RowStatus NOT IN (0, 254)
        AND fa.JobId = j.ID
) AS Amendments

WHERE
    rs.ID > 0
    AND (
        (rs.IsRealStage = 1 AND j.PreConstructionStageFee = 0 AND j.ConstructionStageFee = 0)
        OR (rs.IsRealStage = 0 AND (j.PreConstructionStageFee <> 0 OR j.ConstructionStageFee <> 0))
    )

GROUP BY
    rs.Number,
    rs.Description,
    rs.ID,
    j.RibaStage1Fee,
    j.RibaStage2Fee,
    j.RibaStage3Fee,
    j.RibaStage4Fee,
    j.RibaStage5Fee,
    j.RibaStage6Fee,
    j.RibaStage7Fee,
    j.PreConstructionStageFee,
    j.ConstructionStageFee,
    j.FeeCap,
    j.RowStatus,
    j.Guid,
    j.ID,
	td_agg.TotalNet,
	qi_agg.NumberOfMeetings,
	qi_agg.NumberOfSiteVisits,
	Meetings.SiteVisitTotal,
	Meetings.MeetingTotal,
    Amendments.Stage0Change,
    Amendments.Stage1Change,
    Amendments.Stage2Change,
    Amendments.Stage3Change,
    Amendments.Stage4Change,
    Amendments.Stage5Change,
    Amendments.Stage6Change,
    Amendments.Stage7Change,
    Amendments.PreConstructionStageChange,
    Amendments.ConstructionStageChange,
    Amendments.FeeCapChange,
    Amendments.MeetingsStage0Change,
    Amendments.MeetingsStage1Change,
    Amendments.MeetingsStage2Change,
    Amendments.MeetingsStage3Change,
    Amendments.MeetingsStage4Change,
    Amendments.MeetingsStage5Change,
    Amendments.MeetingsStage6Change,
    Amendments.MeetingsStage7Change,
    Amendments.PreConstructionMeetingChange,
    Amendments.ConstructionMeetingChange,
    Amendments.VisitStage0Change,
    Amendments.VisitStage1Change,
    Amendments.VisitStage2Change,
    Amendments.VisitStage3Change,
    Amendments.VisitStage4Change,
    Amendments.VisitStage5Change,
    Amendments.VisitStage6Change,
    Amendments.VisitStage7Change,
    Amendments.PreConstructionVisitChange,
    Amendments.ConstructionVisitChange


UNION ALL
SELECT
		j.ID,
		j.RowStatus,
		j.Guid,
		N'Total (inc. Fee Cap)',
		N'Total (inc. Fee Cap)',
		j.AgreedFee + j.PreConstructionStageFee + j.ConstructionStageFee + j.RibaStage1Fee + j.RibaStage2Fee
		+ j.RibaStage3Fee + j.RibaStage4Fee + j.RibaStage5Fee + j.RibaStage6Fee + j.RibaStage7Fee + j.FeeCap
		+ ISNULL(Amendments.TotalChange,
		0
		),
		ISNULL(jf.InvoicedValue,
		0
		),
		j.AgreedFee + j.PreConstructionStageFee + j.ConstructionStageFee + j.RibaStage1Fee + j.RibaStage2Fee
		+ j.RibaStage3Fee + j.RibaStage4Fee + j.RibaStage5Fee + j.RibaStage6Fee + j.RibaStage7Fee + j.FeeCap
		+ ISNULL(Amendments.TotalChange,
		0
		) - ISNULL(jf.InvoicedValue,
		0
		),
		ISNULL(Quoted.Meetings,
		0
		) + ISNULL(Amendments.TotalMeetingChange, 0) AS QuotedMeetings,
		ISNULL(Meetings.MeetingTotal,
		0
		) AS CompletedMeetings,
		ISNULL(Quoted.SiteVisits,
		0
		) + ISNULL(Amendments.TotalVisitChange, 0) AS QuotedSiteVisits,
		ISNULL(Meetings.SiteVisitTotal,
		0
		) AS CompletedSiteVisits,
		j.ID,
		-3,
		1
FROM
		SJob.Jobs AS j
LEFT JOIN
		SJob.JobFinance AS jf ON (jf.ID = j.ID)
CROSS APPLY
		(
			SELECT
					SUM(fa.RibaStage0Change + fa.RibaStage1Change + fa.RibaStage2Change + fa.RibaStage3Change + fa.RibaStage4Change
					+ fa.RibaStage5Change + fa.RibaStage6Change + fa.RibaStage7Change + fa.PreConstructionStageChange
					+ fa.ConstructionStageChange + fa.FeeCapChange
					) AS TotalChange,
					SUM(fa.RibaStage0MeetingChange + fa.RibaStage1MeetingChange + fa.RibaStage2MeetingChange + fa.RibaStage3MeetingChange
					+ fa.RibaStage4MeetingChange + fa.RibaStage5MeetingChange + fa.RibaStage6MeetingChange + fa.RibaStage7MeetingChange
					+ fa.PreConstructionStageMeetingChange + fa.ConstructionStageMeetingChange) AS TotalMeetingChange,
					sum (fa.RibaStage0VisitChange + fa.RibaStage1VisitChange + fa.RibaStage2VisitChange + fa.RibaStage3VisitChange
					+ fa.RibaStage4VisitChange + fa.RibaStage5VisitChange + fa.RibaStage6VisitChange + fa.RibaStage7VisitChange
					+ fa.PreConstructionStageVisitChange + fa.ConstructionStageVisitChange)
					AS TotalVisitChange
			FROM
					SJob.FeeAmendment AS fa
			WHERE
					(fa.RowStatus NOT IN (0, 254))
					AND (fa.JobId = j.ID)
		) AS Amendments
OUTER APPLY
		(
			SELECT
					SUM(CASE
							WHEN jat.IsMeeting = 1 THEN
								1
							ELSE
							0
					END
					) AS MeetingTotal,
					SUM(CASE
							WHEN jat.IsSiteVisit = 1 THEN
								1
							ELSE
							0
					END
					) AS SiteVisitTotal
			FROM
					SJob.Activities AS ja
			JOIN
					SJob.ActivityTypes AS jat ON (jat.ID = ja.ActivityTypeID)
			JOIN
					SJob.ActivityStatus AS jas ON (jas.ID = ja.ActivityStatusID)
			WHERE
					(ja.JobId = j.ID)
					AND (jas.Name = N'Complete')
					AND (ja.RowStatus NOT IN (0, 254))
					AND (
							(jat.IsMeeting = 1)
							OR (jat.IsSiteVisit = 1)
					)
		) AS Meetings
OUTER APPLY
		(
			SELECT
					SUM(qi.NumberOfMeetings)   Meetings,
					SUM(qi.NumberOfSiteVisits) SiteVisits

			FROM
					SSop.QuoteItems AS qi
			WHERE
					(qi.CreatedJobId = j.ID)
				AND	(qi.RowStatus NOT IN (0, 254))
		) AS Quoted
GO