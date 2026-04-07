--EXEC SCore.PreDeploymentScript
GO



SET CONCAT_NULL_YIELDS_NULL, ANSI_NULLS, ANSI_PADDING, QUOTED_IDENTIFIER, ANSI_WARNINGS, ARITHABORT, XACT_ABORT ON
SET NUMERIC_ROUNDABORT, IMPLICIT_TRANSACTIONS OFF
GO

BEGIN TRAN 

/****** Object:  View [SJob].[Job_FeeDrawdown]    Script Date: 03/04/2025 11:37:55 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



ALTER   VIEW [SJob].[Job_FeeDrawdown] 
	    --WITH SCHEMABINDING
AS SELECT
		j.ID,
		j.RowStatus,
		j.Guid,
		CASE
				WHEN rs.Number = -1 THEN
					N'Fee Cap'
				ELSE
				CONVERT(NVARCHAR(10),
				rs.Number
				)
		END	  AS Stage,
		CASE
				WHEN rs.Number = -1 THEN
					N'Fee Cap'
				ELSE
				rs.Description
		END	  AS StageLabel,
		CASE rs.Number
				WHEN N'0' THEN
					(0 + ISNULL(Amendments.Stage0Change,
					0
					)
					)
				WHEN N'1' THEN
					(j.RibaStage1Fee + ISNULL(Amendments.Stage1Change,
					0
					)
					)
				WHEN N'2' THEN
					(j.RibaStage2Fee + ISNULL(Amendments.Stage2Change,
					0
					)
					)
				WHEN N'3' THEN
					(j.RibaStage3Fee + ISNULL(Amendments.Stage3Change,
					0
					)
					)
				WHEN N'4' THEN
					(j.RibaStage4Fee + ISNULL(Amendments.Stage4Change,
					0
					)
					)
				WHEN N'5' THEN
					(j.RibaStage5Fee + ISNULL(Amendments.Stage5Change,
					0
					)
					)
				WHEN N'6' THEN
					(j.RibaStage6Fee + ISNULL(Amendments.Stage6Change,
					0
					)
					)
				WHEN N'7' THEN
					(j.RibaStage7Fee + ISNULL(Amendments.Stage7Change,
					0
					)
					)
				WHEN N'99' THEN
					(j.PreConstructionStageFee + ISNULL(Amendments.PreConstructionStageChange,
					0
					)
					)
				WHEN N'999' THEN
					(j.ConstructionStageFee + ISNULL(Amendments.ConstructionStageChange,
					0
					)
					)
				ELSE
				(j.FeeCap + ISNULL(Amendments.FeeCapChange,
				0
				)
				)
		END	  AS Agreed,
		SUM(ISNULL(td.Net,
		0
		))	  AS Invoiced,
		CASE rs.Number
				WHEN N'0' THEN
					0
				WHEN N'1' THEN
					j.RibaStage1Fee
				WHEN N'2' THEN
					j.RibaStage2Fee
				WHEN N'3' THEN
					j.RibaStage3Fee
				WHEN N'4' THEN
					j.RibaStage4Fee
				WHEN N'5' THEN
					j.RibaStage5Fee
				WHEN N'6' THEN
					j.RibaStage6Fee
				WHEN N'7' THEN
					j.RibaStage7Fee
				ELSE
				j.FeeCap
		END - SUM(ISNULL(td.Net,
		0
		))	  AS Remaining,
		SUM(ISNULL(qi.NumberOfMeetings,
		0
		))
		+ CASE rs.Number
				WHEN N'0' THEN
					ISNULL(Amendments.MeetingsStage0Change,
					0
					)
				WHEN N'1' THEN
					ISNULL(Amendments.MeetingsStage1Change,
					0
					)
				WHEN N'2' THEN
					ISNULL(Amendments.MeetingsStage2Change,
					0
					)
				WHEN N'3' THEN
					ISNULL(Amendments.MeetingsStage3Change,
					0
					)
				WHEN N'4' THEN
					ISNULL(Amendments.MeetingsStage4Change,
					0
					)
				WHEN N'5' THEN
					ISNULL(Amendments.MeetingsStage5Change,
					0
					)
				WHEN N'6' THEN
					ISNULL(Amendments.MeetingsStage6Change,
					0
					)
				WHEN N'7' THEN
					ISNULL(Amendments.MeetingsStage7Change,
					0
					)
				WHEN N'99' THEN
					ISNULL(Amendments.PreConstructionMeetingChange,
					0
					)
				WHEN N'999' THEN
					ISNULL(Amendments.ConstructionMeetingChange,
					0
					)
				ELSE
					0
		END	 		
		AS QuotedMeetings,
		ISNULL(Meetings.MeetingTotal,
		0
		)	  AS CompletedMeetings,
		SUM(ISNULL(qi.NumberOfSiteVisits,
		0
		))	  
		
		+ CASE rs.Number
				WHEN N'0' THEN
					ISNULL(Amendments.VisitStage0Change,
					0
					)
				WHEN N'1' THEN
					ISNULL(Amendments.VisitStage1Change,
					0
					)
				WHEN N'2' THEN
					ISNULL(Amendments.VisitStage2Change,
					0
					)
				WHEN N'3' THEN
					ISNULL(Amendments.VisitStage3Change,
					0
					)
				WHEN N'4' THEN
					ISNULL(Amendments.VisitStage4Change,
					0
					)
				WHEN N'5' THEN
					ISNULL(Amendments.VisitStage5Change,
					0
					)
				WHEN N'6' THEN
					ISNULL(Amendments.VisitStage6Change,
					0
					)
				WHEN N'7' THEN
					ISNULL(Amendments.VisitStage7Change,
					0
					)
				WHEN N'99' THEN
					ISNULL(Amendments.PreConstructionVisitChange,
					0
					)
				WHEN N'999' THEN
					ISNULL(Amendments.ConstructionVisitChange,
					0
					)
				ELSE
					0
		END	 		
		
		
		
		AS QuotedSiteVisits,
		ISNULL(Meetings.SiteVisitTotal,
		0
		)	  AS CompletedSiteVisits,
		j.ID  AS JobId,
		rs.ID AS StageId
FROM
		SJob.Jobs AS j
CROSS JOIN
		SJob.RibaStages AS rs
LEFT JOIN
		SJob.Activities AS a ON (a.RibaStageId = rs.ID)
				AND (a.JobId = j.ID)
				AND	(a.RowStatus NOT IN (0, 254))
OUTER APPLY
		(
			SELECT
					td.Net *
							CASE
									WHEN tt.IsNegated = 1 THEN
										-1
									ELSE
									1
							END AS Net
			FROM
					SFin.TransactionDetails AS td
			JOIN
					SFin.Transactions AS t ON (t.ID = td.TransactionID)
			JOIN
					SFin.TransactionTypes AS tt ON (tt.ID = t.TransactionTypeID)
			WHERE
					(td.ActivityID = a.ID)
					AND (tt.IsBank = 0)
					AND (td.RowStatus NOT IN (0, 254))
					AND (t.RowStatus NOT IN (0, 254))
		) AS td
LEFT JOIN
		SSop.QuoteItems AS qi ON (qi.CreatedJobId = j.ID)
			AND	(qi.ProvideAtStageID = rs.ID)
			AND (qi.RowStatus NOT IN (0, 254))

OUTER APPLY
		(
			SELECT
					SUM(fa.RibaStage0Change)		   AS Stage0Change,
					SUM(fa.RibaStage1Change)		   AS Stage1Change,
					SUM(fa.RibaStage2Change)		   AS Stage2Change,
					SUM(fa.RibaStage3Change)		   AS Stage3Change,
					SUM(fa.RibaStage4Change)		   AS Stage4Change,
					SUM(fa.RibaStage5Change)		   AS Stage5Change,
					SUM(fa.RibaStage6Change)		   AS Stage6Change,
					SUM(fa.RibaStage7Change)		   AS Stage7Change,
					SUM(fa.PreConstructionStageChange) AS PreConstructionStageChange,
					SUM(fa.ConstructionStageChange)	   AS ConstructionStageChange,
					SUM(fa.FeeCapChange)			   AS FeeCapChange, 
					SUM(fa.RibaStage0MeetingChange)	   AS MeetingsStage0Change,
					SUM(fa.RibaStage1MeetingChange)	   AS MeetingsStage1Change,
					SUM(fa.RibaStage2MeetingChange)	   AS MeetingsStage2Change,
					SUM(fa.RibaStage3MeetingChange)	   AS MeetingsStage3Change,
					SUM(fa.RibaStage4MeetingChange)	   AS MeetingsStage4Change,
					SUM(fa.RibaStage5MeetingChange)	   AS MeetingsStage5Change,
					SUM(fa.RibaStage6MeetingChange)	   AS MeetingsStage6Change,
					SUM(fa.RibaStage7MeetingChange)	   AS MeetingsStage7Change,
					SUM(fa.PreConstructionStageMeetingChange) AS PreConstructionMeetingChange,
					SUM(fa.ConstructionStageMeetingChange) AS ConstructionMeetingChange,
					SUM(fa.RibaStage0VisitChange)	   AS VisitStage0Change,
					SUM(fa.RibaStage1VisitChange)	   AS VisitStage1Change,
					SUM(fa.RibaStage2VisitChange)	   AS VisitStage2Change,
					SUM(fa.RibaStage3VisitChange)	   AS VisitStage3Change,
					SUM(fa.RibaStage4VisitChange)	   AS VisitStage4Change,
					SUM(fa.RibaStage5VisitChange)	   AS VisitStage5Change,
					SUM(fa.RibaStage6VisitChange)	   AS VisitStage6Change,
					SUM(fa.RibaStage7VisitChange)	   AS VisitStage7Change,
					SUM(fa.PreConstructionStageVisitChange) AS PreConstructionVisitChange,
					SUM(fa.ConstructionStageVisitChange) AS ConstructionVisitChange
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
					AND (ja.RibaStageId = rs.ID)
		) AS Meetings
WHERE
		(rs.ID > 0)
		AND (
				(
						(rs.IsRealStage = 1)
						AND (
								(j.PreConstructionStageFee = 0)
								AND (j.ConstructionStageFee = 0)
						)
				)
				OR (
						(rs.IsRealStage = 0)
						AND (
								(j.PreConstructionStageFee <> 0)
								OR (j.ConstructionStageFee <> 0)
						)
				)
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
		Amendments.FeeCapChange,
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
        Amendments.ConstructionVisitChange,
		Meetings.MeetingTotal,
		Meetings.SiteVisitTotal
UNION ALL
SELECT
		j.ID,
		j.RowStatus,
		j.Guid,
		N'Total (ex. Fee Cap.)',
		N'Total (ex. Fee Cap.)',
		j.AgreedFee + j.PreConstructionStageFee + j.ConstructionStageFee + j.RibaStage1Fee + j.RibaStage2Fee
		+ j.RibaStage3Fee + j.RibaStage4Fee + j.RibaStage5Fee + j.RibaStage6Fee + j.RibaStage7Fee
		+ ISNULL(Amendments.TotalChange,
		0
		),
		ISNULL(jf.InvoicedValue,
		0
		),
		j.AgreedFee + j.PreConstructionStageFee + j.ConstructionStageFee + j.RibaStage1Fee + j.RibaStage2Fee
		+ j.RibaStage3Fee + j.RibaStage4Fee + j.RibaStage5Fee + j.RibaStage6Fee + j.RibaStage7Fee
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
		-2
FROM
		SJob.Jobs AS j
LEFT JOIN
		SJob.JobFinance AS jf ON (jf.ID = j.ID)
CROSS APPLY
		(
			SELECT
					SUM(fa.RibaStage0Change + fa.RibaStage1Change + fa.RibaStage2Change + fa.RibaStage3Change + fa.RibaStage4Change
					+ fa.RibaStage5Change + fa.RibaStage6Change + fa.RibaStage7Change + fa.PreConstructionStageChange
					+ fa.ConstructionStageChange
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
		) AS Quoted
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
		-3
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


SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

ALTER VIEW [SSop].[Quote_CalculatedFields]
   --WITH SCHEMABINDING
AS
SELECT	q.ID,
		CASE
			WHEN  (q.DateAccepted IS NOT NULL) AND (EXISTS
					   (
						   SELECT	1
						   FROM		SSop.QuoteItems	   AS qi
						   WHERE	(qi.QuoteId		 = q.ID)
								AND (qi.CreatedJobId > 0)
								AND	(qi.RowStatus NOT IN (0,254))
					   )
				 ) THEN N'Complete'
			WHEN q.DateDeclinedToQuote IS NOT NULL THEN N'Declined To Quote'
			WHEN q.DeadDate IS NOT NULL THEN N'Dead'
			WHEN q.DateAccepted IS NOT NULL THEN N'Accepted'
			WHEN q.DateRejected IS NOT NULL THEN N'Rejected'
			WHEN q.ExpiryDate < GETUTCDATE () THEN N'Expired'
			WHEN q.DateSent IS NOT NULL THEN N'Sent'
			WHEN q.IsFinal = 1 THEN N'Ready to Send'
			ELSE N'New'
		END AS QuoteStatus
FROM	SSop.Quotes AS q
GO


SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
ALTER FUNCTION [SJob].[tvf_Jobs_CDM_MyProjects]
(
    @UserID INT
)
RETURNS TABLE
AS
RETURN
WITH MilestoneData
AS (SELECT JobID,
           MAX(   CASE
                      WHEN MilestoneTypeID = 8 THEN
                          1
                      ELSE
                          0
                  END
              ) AS HasHSFile,
           MAX(   CASE
                      WHEN MilestoneTypeID = 2
                           AND IsComplete = 1 THEN
                          1
                      ELSE
                          0
                  END
              ) AS ClientDutiesIssued,
           MAX(   CASE
                      WHEN MilestoneTypeID = 1
                           AND IsComplete = 1 THEN
                          1
                      ELSE
                          0
                  END
              ) AS CDMStrategyIssued,
           MAX(   CASE
                      WHEN MilestoneTypeID = 11
                           AND IsComplete = 1 THEN
                          1
                      ELSE
                          0
                  END
              ) AS PCICompleted,
           MAX(   CASE
                      WHEN MilestoneTypeID = 7 THEN
                          1
                      ELSE
                          0
                  END
              ) AS F10Applicable,
           MAX(   CASE
                      WHEN MilestoneTypeID = 19 THEN
                          CompletedDateTimeUTC
                  END
              ) AS CPPDateReceived,
           MAX(   CASE
                      WHEN MilestoneTypeID = 17 THEN
                          CompletedDateTimeUTC
                  END
              ) AS CPPReviewed,
           MAX(   CASE
                      WHEN MilestoneTypeID = 8 THEN
                          ReviewedDateTimeUTC
                  END
              ) AS HSFReviewedDate,
           MAX(   CASE
                      WHEN MilestoneTypeID = 8 THEN
                          CompletedDateTimeUTC
                  END
              ) AS HSFCompletedDate,
           -- New aggregated F10 dates
           MAX(   CASE
                      WHEN MilestoneTypeID = 7 THEN
                          CompletedDateTimeUTC
                  END
              ) AS F10IssuedDate,
           MAX(   CASE
                      WHEN MilestoneTypeID = 7 THEN
                          StartDateTimeUTC
                  END
              ) AS F10StartDate,
           MAX(   CASE
                      WHEN MilestoneTypeID = 7 THEN
                          DueDateTimeUTC
                  END
              ) AS F10DueDate,
           MAX(   CASE
                      WHEN MilestoneTypeID = 7 THEN
                          SubmissionExpiryDate
                  END
              ) AS F10ExpiryDate,
           MAX(   CASE
                      WHEN MilestoneTypeID = 11 THEN
                          CompletedDateTimeUTC
                  END
              ) AS PCIDate
    FROM SJob.Milestones
    GROUP BY JobID),
     FeeData
AS (SELECT JobId,
           MAX(   CASE
                      WHEN StageId = -2 THEN
                          Agreed
                  END
              ) AS TotalAgreed,
           MAX(   CASE
                      WHEN StageId = -2 THEN
                          Remaining
                  END
              ) AS TotalRemaining,
           MAX(   CASE
                      WHEN StageId = 10 THEN
                          QuotedMeetings
                  END
              ) AS PreConMeetings,
           MAX(   CASE
                      WHEN StageId = 11 THEN
                          QuotedMeetings
                  END
              ) AS ConMeetings,
           MAX(   CASE
                      WHEN StageId = 10 THEN
                          QuotedMeetings - CompletedMeetings
                  END
              ) AS PreConRemaining,
           MAX(   CASE
                      WHEN StageId = 11 THEN
                          QuotedMeetings - CompletedMeetings
                  END
              ) AS ConRemaining
    FROM SJob.Job_FeeDrawdown
    GROUP BY JobId),
     ActivityData
AS (SELECT JobID,
           COUNT(   CASE
                        WHEN ActivityTypeID = 23 THEN
                            ID
                    END
                ) AS TotalComplianceVisits,
           COUNT(   CASE
                        WHEN ActivityTypeID = 23
                             AND ActivityStatusID = 3 THEN
                            ID
                    END
                ) AS CompletedComplianceVisits,
           MAX(   CASE
                      WHEN ActivityTypeID = 26
                           AND ActivityStatusID = 3 THEN
                          EndDate
                  END
              ) AS DRRLastIssued
    FROM SJob.Activities
    GROUP BY JobID)
SELECT j.ID,
       j.Guid,
       j.RowStatus,
       -- [PROJECT]
       /*CASE 
           WHEN EXISTS(SELECT 1 FROM SSop.Projects p WHERE p.ID = j.ProjectId AND p.ExternalReference = '')
           THEN CAST(j.ProjectId AS NVARCHAR(15))
           ELSE CAST(j.ProjectId AS NVARCHAR(15)) + N' - ' + CAST(j.ExternalReference AS NVARCHAR(50))
       END*/

       j.Number AS projectRef,
       client.Name + N' / ' + agent.Name AS clientAgent,
       p.Name + N' / ' + p.FormattedAddressComma AS propertyName,
       jt.Name AS CDMRole,
       js.JobStatus,
       -- [FINANCE]
       fd.TotalAgreed AS totalAgreed,
       fd.TotalRemaining AS totalRemaining,
       -- [AGREED DELIVERABLES]
       fd.PreConMeetings AS preconMeetings,
       fd.ConMeetings AS conMeetings,
       ad.TotalComplianceVisits AS complianceVisit,
       CASE
           WHEN md.HasHSFile = 1 THEN
               N'Yes'
           ELSE
               N'No'
       END AS hsFile,
       -- [REMAINING DELIVERABLES]
       fd.PreConRemaining AS preconMeetingsRemaining,
       fd.ConRemaining AS conMeetingsRemaining,
       (ad.TotalComplianceVisits - ad.CompletedComplianceVisits) AS compVisitsRemaining,
       CASE
           WHEN EXISTS
                (
                    SELECT 1
                    FROM SJob.Milestones m
                    WHERE m.JobID = j.ID
                          AND m.MilestoneTypeID = 8
                          AND m.IsComplete = 1
                ) THEN
               N'Yes'
           ELSE
               N'No'
       END AS HSIssued,
       -- [CLIENT DUTIES]
       CASE
           WHEN md.ClientDutiesIssued = 1 THEN
               N'Yes'
           ELSE
               N'No'
       END AS clientDutiesIssued,
       CASE
           WHEN md.CDMStrategyIssued = 1 THEN
               N'Yes'
           ELSE
               N'No'
       END AS CDMStrategyIssued,
       -- [PCI]
       CASE
           WHEN md.PCICompleted = 1 THEN
               N'Yes'
           ELSE
               N'No'
       END AS PCIInspectionCompleted,
       CAST(md.PCIDate AS DATE) AS PCIDate,
       -- [RISK]
       CAST(ad.DRRLastIssued AS DATE) AS DRRLastIssued,
       -- [F10]
       CASE
           WHEN md.F10Applicable = 1 THEN
               N'Yes'
           ELSE
               N'No'
       END AS F10Applicable,
       CAST(md.F10IssuedDate AS DATE) AS F10IssuedDate,
       CAST(md.F10StartDate AS DATE) AS F10Start,
       DATEDIFF(WEEK, md.F10StartDate, md.F10DueDate) AS F10WeekDuration,
       CAST(md.F10ExpiryDate AS DATE) AS F10ExpiryDate,
       -- [CPP]
       CAST(md.CPPDateReceived AS DATE) AS CPPDateReceived,
       CAST(md.CPPReviewed AS DATE) AS CPPReviewed,
       -- [H&S FILE]
       CAST(md.HSFReviewedDate AS DATE) AS HSFReviewed,
       CAST(md.HSFCompletedDate AS DATE) AS HSFCompleted
FROM SJob.Jobs j
    JOIN SJob.JobStatus js
        ON js.ID = j.ID
    JOIN SJob.Properties p
        ON p.ID = j.UprnID
    JOIN SJob.JobTypes jt
        ON jt.ID = j.JobTypeID
    JOIN SCrm.Accounts client
        ON client.ID = j.ClientAccountID
    JOIN SCrm.Accounts agent
        ON agent.ID = j.AgentAccountID
    LEFT JOIN MilestoneData md
        ON md.JobID = j.ID
    LEFT JOIN FeeData fd
        ON fd.JobId = j.ID
    LEFT JOIN ActivityData ad
        ON ad.JobID = j.ID
WHERE j.IsActive = 1
      AND j.RowStatus NOT IN ( 0, 254 )
      AND j.SurveyorID = @UserID
      AND j.ID > 0
      AND EXISTS
(
    SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserID)
);
GO 





EXEC sys.sp_set_session_context @key = 'S_disable_triggers',
								@value = 1;

UPDATE	p
SET		p.ProjectDescription = N'Auto Generated Project for Quote ' + CONVERT(NVARCHAR(MAX), q.Number) + N' - ' + q.Overview
FROM	SSop.Projects AS p
JOIN	SSop.Quotes AS q ON (q.ProjectId = p.ID)
WHERE	(p.ProjectDescription = N'')

UPDATE	p
SET		p.ProjectDescription = N'Auto Generated Project for Enquiry ' + CONVERT(NVARCHAR(MAX), e.Number) + N' - ' + e.DescriptionOfWorks
FROM	SSop.Projects AS p
JOIN	SSop.Enquiries AS e ON (e.ProjectId = p.ID)
WHERE	(p.ProjectDescription = N'')

UPDATE	p
SET		p.ProjectDescription = N'Auto Generated Project for Job ' + CONVERT(NVARCHAR(MAX), j.Number) + N' - ' + j.JobDescription
FROM	SSop.Projects AS p
JOIN	SJob.Jobs AS j ON (j.ProjectId = p.ID)
WHERE	(p.ProjectDescription = N'')

UPDATE	p
SET		p.RowStatus = 254
FROM	SSop.Projects p
WHERE	(ProjectDescription = N'')
	AND	(p.RowStatus NOT IN (0, 254))
	AND	(NOT EXISTS
			(
				SELECT 1
				FROM	SSop.Enquiries e
				WHERE	(e.ProjectId = p.ID)
			)
		)
	AND	(NOT EXISTS
			(
				SELECT	1
				FROM	SSop.Quotes q
				WHERE	(q.ProjectId = p.ID)
			)
		)
	AND	(NOT EXISTS
			(
				SELECT	1
				FROM	SJob.Jobs j 
				WHERE	(j.ProjectId = p.ID)
			)
		)


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [SSop].[tvf_Quotes]
(
	@UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.FullNumber AS Number,
		LEFT(q.Overview, 200) AS Details, 
		acc.Name + N' / ' + agent.Name AS Account,
		uprn.FormattedAddressComma,
		qcf.QuoteStatus AS QuoteStatus,
		i.FullName AS QuotingConsultant,
		ou.Name AS OrganisationalUnitName,
		jt.Name AS JobType
FROM    SSop.Quotes q
JOIN	SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
JOIN	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN	SCrm.Accounts acc ON (acc.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountId)
JOIN	SJob.Properties uprn ON (uprn.ID = e.PropertyId)
JOIN	SCore.Identities i ON (i.ID = q.QuotingConsultantId)
JOIN    SCore.OrganisationalUnits ou ON q.OrganisationalUnitID = ou.ID
JOIN	SJob.JobTypes AS jt ON (jt.ID = es.JobTypeId)
WHERE   (q.ID > 0)
AND	
(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [SSop].[Quote_CalculatedFields]
   --WITH SCHEMABINDING
AS
SELECT	q.ID,
		CASE
			WHEN  (q.DateAccepted IS NOT NULL) AND (EXISTS
					   (
						   SELECT	1
						   FROM		SSop.QuoteItems	   AS qi
						   WHERE	(qi.QuoteId		 = q.ID)
								AND (qi.CreatedJobId > 0)
								AND	(qi.RowStatus NOT IN (0,254))
					   )
				 ) THEN N'Complete'
			WHEN q.DateDeclinedToQuote IS NOT NULL THEN N'Declined To Quote'
			WHEN q.DeadDate IS NOT NULL THEN N'Dead'
			WHEN q.DateAccepted IS NOT NULL THEN N'Accepted'
			WHEN q.DateRejected IS NOT NULL THEN N'Rejected'
			WHEN q.ExpiryDate < GETUTCDATE () THEN N'Expired'
			WHEN q.DateSent IS NOT NULL THEN N'Sent'
			WHEN q.IsFinal = 1 THEN N'Ready to Send'
			ELSE N'New'
		END AS QuoteStatus
FROM	SSop.Quotes AS q
GO


DECLARE	@QuotesWithoutEnquiries TABLE
(
	ID INT IDENTITY(1,1) NOT NULL, 
	QuoteID INT NOT NULL,
	EnquiryGuid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
	EnquiryId INT NOT NULL DEFAULT (-1),
	EnquiryServiceGuid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
	EnquiryServiceID INT NOT NULL DEFAULT (-1),
	UPRNID INT NOT NULL,
	ProjectID INT NOT NULL, 
	[Date] DATE NOT NULL,
	QuotingUserID INT NOT NULL,
	Number NVARCHAR(50) NOT NULL, 
	OrganisationalUnitID INT NOT NULL, 
	ClientAccountID INT NOT NULL, 
	ClientAddressID INT NOT NULL, 
	ClientContactID INT NOT NULL, 
	AgentAccountID INT NOT NULL,
	AgentAddressID INT NOT NULL, 
	AgentContactID INT NOT NULL, 
	Overview NVARCHAR(MAX) NOT NULL, 
	IsSubjectToNDA BIT NOT NULL,
	ExternalReference NVARCHAR(50) NOT NULL,
	SendInfoToClient BIT NOT NULL,
	SendInfoToAgent BIT NOT NULL,
	ValueOfWork DECIMAL(19,2) NOT NULL,
	CurrentRibaStageID INT NOT NULL,
	QuoteSourceID INT NOT NULL, 
	SignatoryID INT NOT NULL,
	DeadDate DATE NULL, 
	ChaseDate1 DATE NULL, 
	ChaseDate2 DATE NULL,
	JobTypeID INT NOT NULL
)

INSERT INTO @QuotesWithoutEnquiries
(
    QuoteID,
    UPRNID,
    ProjectID,
    Date,
    QuotingUserID,
    Number,
    OrganisationalUnitID,
    ClientAccountID,
    ClientAddressID,
    ClientContactID,
    AgentAccountID,
    AgentAddressID,
    AgentContactID,
    Overview,
    IsSubjectToNDA,
    ExternalReference,
	SendInfoToClient,
	SendInfoToAgent,
	ValueOfWork,
	CurrentRibaStageID,
	QuoteSourceID,
	SignatoryID,
	DeadDate,
	ChaseDate1,
	ChaseDate2,
	JobTypeID
)
SELECT
    q.ID,         -- QuoteID - int
    q.UprnId,         -- UPRNID - int
    q.ProjectId,         -- ProjectID - int
    q.Date, -- Date - date
    q.QuotingUserId,         -- QuotingUserID - int
    CASE WHEN ISNUMERIC(q.Number) = 1 THEN N'Q-' + q.Number ELSE q.Number END AS Number,       -- Number - nvarchar(50)
    q.OrganisationalUnitID,         -- OrganisationalUnitID - int
    q.ClientAccountId,         -- ClientAccountID - int
    q.ClientAddressId,         -- ClientAddressID - int
    q.ClientContactId,         -- ClientContactID - int
    q.AgentAccountId,         -- AgentAccountID - int
    q.AgentAddressId,         -- AgentAddressID - int
    q.AgentContactId,         -- AgentContactID - int
    q.Overview,       -- Overview - nvarchar(max)
    q.IsSubjectToNDA,      -- IsSubjectToNDA - bit
    q.ExternalReference,       -- ExternalReference - nvarchar(50)
	q.SendInfoToClient,
	q.SendInfoToAgent,
	q.ValueOfWork,
	q.CurrentRibaStageId,
	q.QuoteSourceId,
	ISNULL(Sig.ID, -1),
	q.DeadDate,
	q.ChaseDate1,
	q.ChaseDate2, 
	ISNULL(jt.ID, -1)
FROM	SSop.Quotes q
OUTER APPLY
(
	SELECT	TOP (1) ou.ID	
	FROM	SCore.OrganisationalUnits AS ou 
	WHERE	(ou.ID = q.OrganisationalUnitID)
		AND	(ou.IsBusinessUnit = 1)
) AS Bu
OUTER APPLY
(
	SELECT	TOP(1) ou2.ID	
	FROM	SCore.OrganisationalUnits AS ou 
	JOIN	SCore.OrganisationalUnits AS ou2 ON (ou2.ID = ou.ParentID)
	WHERE	(ou.ID = q.OrganisationalUnitID)
		AND	(ou.IsDepartment = 1)
) AS Dpt
OUTER APPLY 
(
	SELECT	TOP(1) i.ID	
	FROM	SCore.Identities AS i 
	WHERE	(i.FullName IN (N'Neil Fenn', N'Ryan Fitzgerald', N'Mick Cahill'))
	AND		(i.OriganisationalUnitId = ISNULL(bu.ID, dpt.ID))
) AS Sig
OUTER APPLY 
(
	SELECT	TOP(1) jt.ID
	FROM	SSop.QuoteItems qi 
	JOIN	SProd.Products p ON (p.ID = qi.ProductId)
	JOIN	SJob.JobTypes jt ON (jt.ID = p.CreatedJobType)
	WHERE	(qi.QuoteId = q.ID)
		AND	(qi.RowStatus NOT IN (0, 254))
	ORDER BY qi.ID
) AS Jt
WHERE	(q.EnquiryServiceID < 0)
	AND	(q.ID > 0)



DECLARE @GuidList SCore.GuidUniqueList


/* 
	Create the required Enquiries. 
*/
INSERT	@GuidList
(
    GuidValue
)
SELECT	EnquiryGuid
FROM	@QuotesWithoutEnquiries

DECLARE @IsInsert BIT;
EXEC SCore.DataObjectBulkUpsert @GuidList = @GuidList,            -- GuidUniqueList
                                @SchemeName = N'SSop',           -- nvarchar(255)
                                @ObjectName = N'Enquiries',           -- nvarchar(255)
                                @IncludeDefaultSecurity = 0, -- bit
                                @IsInsert = @IsInsert OUTPUT -- bit

INSERT	SSop.Enquiries
(
    RowStatus,
    Guid,
    OrganisationalUnitID,
    Date,
    CreatedByUserId,
    Number,
    Revision,
    OriginalEnquiryId,
    PropertyId,
    ClientAccountId,
    ClientAddressId,
    ClientAccountContactId,
    AgentAccountId,
    AgentAddressId,
    AgentAccountContactId,
    DescriptionOfWorks,
    ValueOfWork,
    CurrentProjectRibaStageID,
    SendInfoToClient,
    SendInfoToAgent,
    EnquirySourceId,
    IsReadyForQuoteReview,
    QuotingDeadlineDate,
    ExternalReference,
    ProjectId,
    IsSubjectToNDA,
    DeadDate,
    ChaseDate1,
    ChaseDate2,
    SignatoryIdentityId
)
SELECT
	1, -- RowStatus - tinyint
    EnquiryGuid, -- Guid - uniqueidentifier
    OrganisationalUnitID, -- OrganisationalUnitID - int
    [Date], -- Date - datetime2(7)
    QuotingUserID, -- CreatedByUserId - int
    Number, -- Number - nvarchar(50)
    0, -- Revision - int
    -1, -- OriginalEnquiryId - int
    UPRNID, -- PropertyId - int
    ClientAccountID, -- ClientAccountId - int
    ClientAddressID, -- ClientAddressId - int
    ClientContactID, -- ClientAccountContactId - int
    AgentAccountID, -- AgentAccountId - int
    AgentAddressID, -- AgentAddressId - int
    AgentContactID, -- AgentAccountContactId - int
    Overview, -- DescriptionOfWorks - nvarchar(4000)
    ValueOfWork, -- ValueOfWork - decimal(19, 2)
    CurrentRibaStageID, -- CurrentProjectRibaStageID - int
    SendInfoToClient, -- SendInfoToClient - bit
    SendInfoToAgent, -- SendInfoToAgent - bit
    QuoteSourceID, -- EnquirySourceId - int
    1, -- IsReadyForQuoteReview - bit
    NULL,    -- QuotingDeadlineDate - date
    ExternalReference, -- ExternalReference - nvarchar(50)
    ProjectID, -- ProjectId - int
    IsSubjectToNDA, -- IsSubjectToNDA - bit
    DeadDate,    -- DeadDate - date
    ChaseDate1,    -- ChaseDate1 - date
    ChaseDate2,    -- ChaseDate2 - date
    SignatoryID -- SignatoryIdentityId - int
FROM	@QuotesWithoutEnquiries


UPDATE	qwe
SET		qwe.EnquiryId = e.ID
FROM	@QuotesWithoutEnquiries qwe
JOIN	SSop.Enquiries e ON (e.Guid = qwe.EnquiryGuid)

/*
	Create the Enquiry Services 	
*/

DELETE	@GuidList

INSERT @GuidList
(
    GuidValue
)
SELECT	EnquiryServiceGuid
FROM	@QuotesWithoutEnquiries

EXEC SCore.DataObjectBulkUpsert @GuidList = @GuidList,            -- GuidUniqueList
                                @SchemeName = N'SSop',           -- nvarchar(255)
                                @ObjectName = N'EnquiryServices',           -- nvarchar(255)
                                @IncludeDefaultSecurity = 1, -- bit
                                @IsInsert = @IsInsert OUTPUT -- bit

INSERT	SSop.EnquiryServices
(
    RowStatus,
    Guid,
    EnquiryId,
    JobTypeId,
    StartRibaStageId,
    EndRibaStageId,
    QuoteId
)
SELECT	
	1, -- RowStatus - tinyint
    EnquiryServiceGuid, -- Guid - uniqueidentifier
    EnquiryId, -- EnquiryId - int
    JobTypeID, -- JobTypeId - int
    -1, -- StartRibaStageId - int
    -1, -- EndRibaStageId - int
    -1  -- QuoteId - int
FROM	@QuotesWithoutEnquiries

UPDATE	qwe
SET		qwe.EnquiryServiceID = es.ID
FROM	@QuotesWithoutEnquiries qwe
JOIN	SSop.EnquiryServices es ON (es.Guid = qwe.EnquiryServiceGuid)


/* 
	Link the Enquiry to the Quote 
*/
UPDATE	q
SET		q.EnquiryServiceID = qwe.EnquiryServiceID
FROM	SSop.Quotes q
JOIN	@QuotesWithoutEnquiries qwe ON (qwe.QuoteID = q.ID)
WHERE	(q.EnquiryServiceID < 0)



UPDATE	e
SET		PropertyID = q.UprnId
FROM	SSop.Enquiries e
JOIN	SSop.EnquiryServices es ON (es.EnquiryId = e.ID)
JOIN	SSop.Quotes q ON (q.EnquiryServiceID = es.ID)
WHERE	(e.PropertyId < 0) 
	AND (e.IsReadyForQuoteReview = 1)



SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






ALTER FUNCTION [SSop].[tvf_CurrentQuotes]
(
	@UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.FullNumber AS Number,
		CASE WHEN q.DescriptionOfWorks <> N'' THEN LEFT(q.DescriptionOfWorks, 200) ELSE LEFT(q.Overview, 200) END AS Details, --[CBLD-640]
		--LEFT(q.Overview, 200) AS Details, 
		acc.Name + N' / ' + agent.Name AS Account,
		uprn.FormattedAddressComma,
		qcf.QuoteStatus,
		i.FullName AS QuotingConsultant,
		q.RevisionNumber,
		ou.Name AS OrganisationalUnitName
FROM    SSop.Quotes q
JOIN	SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
JOIN	SCrm.Accounts acc ON (acc.ID = q.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = q.AgentAccountId)
JOIN	SJob.Properties uprn ON (uprn.ID = q.UprnId)
JOIN	SCore.Identities i ON (i.ID = q.QuotingConsultantId)
JOIN    SCore.OrganisationalUnits ou ON q.OrganisationalUnitID = ou.ID
WHERE   (q.RowStatus NOT IN (0, 254))
	AND	(q.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
	AND	(
			(q.DateAccepted IS NULL)
			OR 
			(
				(q.DateAccepted IS NOT NULL)
				AND (EXISTS 
						(
							SELECT	1
							FROM	SSop.QuoteItems qi
							JOIN	SSop.QuoteSections qs ON (qs.ID = qi.QuoteSectionId)
							WHERE	(qs.QuoteID = q.ID)
								AND	(qi.RowStatus NOT IN (0, 254))
								AND	(qi.CreatedJobId < 0)
						)
					)
			)
		)
	AND	(q.DateRejected IS NULL)
	AND	(q.ExpiryDate > GETDATE())
GO

UPDATE	os
SET		RowStatus = 254
FROM	SCore.ObjectSecurity os
JOIN	SCore.DataObjects do ON (do.Guid = os.ObjectGuid)
JOIN	SCore.EntityTypes et ON (et.id = do.EntityTypeId)
WHERE	(et.Name IN (N'Accounts', N'Addresses', N'Contacts', N'Account Addresses', N'Account Contacts', N'Structures', N'Account Memos'))
GO 




--
-- Drop type [SCore].[TwoGuidUniqueList]
--
DROP TYPE [SCore].[TwoGuidUniqueList]
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Create type [SCore].[TwoGuidUniqueList]
--
CREATE TYPE [SCore].[TwoGuidUniqueList] AS TABLE (
  [GuidValue] [uniqueidentifier] NOT NULL,
  [GuidValueTwo] [uniqueidentifier] NOT NULL,
  PRIMARY KEY CLUSTERED ([GuidValue], [GuidValueTwo]) 
)
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Drop type [SCore].[ThreeGuidUniqueList]
--
DROP TYPE [SCore].[ThreeGuidUniqueList]
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Create type [SCore].[ThreeGuidUniqueList]
--
CREATE TYPE [SCore].[ThreeGuidUniqueList] AS TABLE (
  [GuidValue] [uniqueidentifier] NOT NULL,
  [GuidValueTwo] [uniqueidentifier] NOT NULL,
  [GuidValueThree] [uniqueidentifier] NOT NULL,
  PRIMARY KEY CLUSTERED ([GuidValue], [GuidValueTwo], [GuidValueThree]) 
)
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Drop primary key on table [SCore].[SystemUsageLog]
--
ALTER TABLE [SCore].[SystemUsageLog]
  DROP CONSTRAINT [PK__SystemUs__3214EC0781CE0EE9]
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Create primary key on table [SCore].[SystemUsageLog]
--
ALTER TABLE [SCore].[SystemUsageLog]
  ADD PRIMARY KEY CLUSTERED ([Id]) WITH (FILLFACTOR = 80)
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Create or alter function [SCrm].[tvf_AccountsWithSageCode]
--
GO
CREATE OR ALTER FUNCTION [SCrm].[tvf_AccountsWithSageCode]
(
	@UserId INT
)
RETURNS TABLE
	--WITH SCHEMABINDING
AS 
 RETURN
  SELECT
          a.ID,
          a.RowStatus,
          a.Guid,
          a.Code,
          a.Name,
          astat.Name               AS AccountStatusName,
          rm.FullName              AS RelationshipManagerName,
          ad.FormattedAddressComma AS MainAddress,
          c.DisplayName            AS MainContact
  FROM
          SCrm.Accounts a
  JOIN
          SCrm.AccountStatus astat ON (a.AccountStatusID = astat.ID)
  JOIN
          SCore.Identities rm ON (rm.ID = a.RelationshipManagerUserId)
  JOIN
          SCrm.AccountAddresses aa ON (aa.ID = a.MainAccountAddressId)
  JOIN
          SCrm.Addresses ad ON (ad.ID = aa.AddressID)
  JOIN
          SCrm.AccountContacts ac ON (ac.ID = a.MainAccountContactId)
  JOIN
          SCrm.Contacts c ON (c.ID = ac.ContactID)
  WHERE
          (a.RowStatus NOT IN (0, 254))
          AND (aa.RowStatus NOT IN (0, 254))
          AND (ac.RowStatus NOT IN (0, 254))
          AND (a.ID > 0)
		  AND (a.Code <> '')
          AND (EXISTS
          (
              SELECT
                      1
              FROM
                      SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
          )
          )
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Drop index [IX_UQ_Quotes_Guid] from table [SSop].[Quotes]
--
DROP INDEX [IX_UQ_Quotes_Guid] ON [SSop].[Quotes]
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Create index [IX_UQ_Quotes_Guid] on table [SSop].[Quotes]
--
CREATE UNIQUE INDEX [IX_UQ_Quotes_Guid]
  ON [SSop].[Quotes] ([Guid])
  INCLUDE ([RowStatus])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Create index [IX_Quote_Status] on table [SSop].[Quotes]
--
CREATE UNIQUE INDEX [IX_Quote_Status]
  ON [SSop].[Quotes] ([ID])
  INCLUDE ([IsFinal], [ExpiryDate], [DateSent], [DateAccepted], [DateRejected], [DeadDate], [DateDeclinedToQuote])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Create or alter function [SSop].[tvf_Quotes]
--
GO
CREATE OR ALTER FUNCTION [SSop].[tvf_Quotes]
(
	@UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.FullNumber AS Number,
		CASE WHEN q.DescriptionOfWorks <> N'' THEN LEFT(q.DescriptionOfWorks, 200) ELSE LEFT(q.Overview, 200) END AS Details,
		--LEFT(q.Overview, 200) AS Details, 
		acc.Name + N' / ' + agent.Name AS Account,
		uprn.FormattedAddressComma,
		qcf.QuoteStatus AS QuoteStatus,
		i.FullName AS QuotingConsultant,
		ou.Name AS OrganisationalUnitName,
		jt.Name AS JobType
FROM    SSop.Quotes q
JOIN	SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
JOIN	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN	SCrm.Accounts acc ON (acc.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountId)
JOIN	SJob.Properties uprn ON (uprn.ID = e.PropertyId)
JOIN	SCore.Identities i ON (i.ID = q.QuotingConsultantId)
JOIN    SCore.OrganisationalUnits ou ON q.OrganisationalUnitID = ou.ID
JOIN	SJob.JobTypes AS jt ON (jt.ID = es.JobTypeId)
WHERE   (q.ID > 0)
AND	
(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO




SET LANGUAGE 'British English'
SET DATEFORMAT ymd
SET ARITHABORT, ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER, ANSI_NULLS, NOCOUNT, XACT_ABORT ON
SET NUMERIC_ROUNDABORT, IMPLICIT_TRANSACTIONS OFF
GO


--
-- Disabling DML triggers for [SCore].[EntityProperties]
--
GO
DISABLE TRIGGER ALL ON SCore.EntityProperties
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Disabling DML triggers for [SCore].[EntityQueries]
--
GO
DISABLE TRIGGER ALL ON SCore.EntityQueries
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Disabling DML triggers for [SCore].[LanguageLabels]
--
GO
DISABLE TRIGGER ALL ON SCore.LanguageLabels
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Disabling DML triggers for [SCore].[LanguageLabelTranslations]
--
GO
DISABLE TRIGGER ALL ON SCore.LanguageLabelTranslations
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Disabling DML triggers for [SUserInterface].[DropDownListDefinitions]
--
GO
DISABLE TRIGGER ALL ON SUserInterface.DropDownListDefinitions
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[EntityProperties]
--
ALTER TABLE SCore.EntityProperties
  DROP CONSTRAINT IF EXISTS FK_EntityProperties_DropDownListDefinitions
ALTER TABLE SCore.EntityProperties
  DROP CONSTRAINT IF EXISTS FK_EntityProperties_EntityDataTypes
ALTER TABLE SCore.EntityProperties
  DROP CONSTRAINT IF EXISTS FK_EntityProperties_EntityHoBTs
ALTER TABLE SCore.EntityProperties
  DROP CONSTRAINT IF EXISTS FK_EntityProperties_EntityPropertyGroupID
ALTER TABLE SCore.EntityProperties
  DROP CONSTRAINT IF EXISTS FK_EntityProperties_LanguageLabels
ALTER TABLE SCore.EntityProperties
  DROP CONSTRAINT IF EXISTS FK_EntityProperties_RowStatus
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[EntityQueries]
--
ALTER TABLE SCore.EntityQueries
  DROP CONSTRAINT IF EXISTS FK_EntityQueries_EntityHoBTs
ALTER TABLE SCore.EntityQueries
  DROP CONSTRAINT IF EXISTS FK_EntityQueries_EntityTypes
ALTER TABLE SCore.EntityQueries
  DROP CONSTRAINT IF EXISTS FK_EntityQueries_RowStatus
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[LanguageLabels]
--
ALTER TABLE SCore.LanguageLabels
  DROP CONSTRAINT IF EXISTS FK_LanguageLabels_RowStatus
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[LanguageLabelTranslations]
--
ALTER TABLE SCore.LanguageLabelTranslations
  DROP CONSTRAINT IF EXISTS FK_LanguageLabelTranslations_LanguageLabels
ALTER TABLE SCore.LanguageLabelTranslations
  DROP CONSTRAINT IF EXISTS FK_LanguageLabelTranslations_Languages
ALTER TABLE SCore.LanguageLabelTranslations
  DROP CONSTRAINT IF EXISTS FK_LanguageLabelTranslations_RowStatus
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SUserInterface].[DropDownListDefinitions]
--
ALTER TABLE SUserInterface.DropDownListDefinitions
  DROP CONSTRAINT IF EXISTS FK_DropDownListDefinitions_EntityTypes
ALTER TABLE SUserInterface.DropDownListDefinitions
  DROP CONSTRAINT IF EXISTS FK_DropDownListDefinitions_RowStatus
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SUserInterface].[GridViewColumnDefinitions]
--
ALTER TABLE SUserInterface.GridViewColumnDefinitions
  DROP CONSTRAINT IF EXISTS FK_GridViewColumnDefinition_GridViewDefinition
ALTER TABLE SUserInterface.GridViewColumnDefinitions
  DROP CONSTRAINT IF EXISTS FK_GridViewColumnDefinitions_LanguageLabelId
ALTER TABLE SUserInterface.GridViewColumnDefinitions
  DROP CONSTRAINT IF EXISTS FK_GridViewColumnDefinitions_RowStatus
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SUserInterface].[GridViewDefinitions]
--
ALTER TABLE SUserInterface.GridViewDefinitions
  DROP CONSTRAINT IF EXISTS FK_GridViewDefinition_GridDefinition
ALTER TABLE SUserInterface.GridViewDefinitions
  DROP CONSTRAINT IF EXISTS FK_GridViewDefinitions_DrawerIconId
ALTER TABLE SUserInterface.GridViewDefinitions
  DROP CONSTRAINT IF EXISTS FK_GridViewDefinitions_EntityTypes
ALTER TABLE SUserInterface.GridViewDefinitions
  DROP CONSTRAINT IF EXISTS FK_GridViewDefinitions_LanguageLabelId
ALTER TABLE SUserInterface.GridViewDefinitions
  DROP CONSTRAINT IF EXISTS FK_GridViewDefinitions_MetricTypes
ALTER TABLE SUserInterface.GridViewDefinitions
  DROP CONSTRAINT IF EXISTS FK_GridViewDefinitions_RowStatus
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[EntityPropertyActions]
--
ALTER TABLE SCore.EntityPropertyActions
  DROP CONSTRAINT IF EXISTS FK_EntityPropertyActions_EntityProperties
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[EntityPropertyDependants]
--
ALTER TABLE SCore.EntityPropertyDependants
  DROP CONSTRAINT IF EXISTS FK_EntityPropertyDependants_EntityProperties
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[EntityQueryParameters]
--
ALTER TABLE SCore.EntityQueryParameters
  DROP CONSTRAINT IF EXISTS FK_EntityQueryParameters_EntityProperties
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[MergeDocumentItemIncludes]
--
ALTER TABLE SCore.MergeDocumentItemIncludes
  DROP CONSTRAINT IF EXISTS FK_MergeDocumentItemIncludes_EntityProperties
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[RecordHistory]
--
ALTER TABLE SCore.RecordHistory
  DROP CONSTRAINT IF EXISTS FK_RecordHistory_EntityPropertyID
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[SynchronisationErrors]
--
ALTER TABLE SCore.SynchronisationErrors
  DROP CONSTRAINT IF EXISTS FK_SychronisationErrors_EntityPropertyID
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SUserInterface].[ActionMenuItems]
--
ALTER TABLE SUserInterface.ActionMenuItems
  DROP CONSTRAINT IF EXISTS FK_ActionMenuItems_EntityQueries
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SUserInterface].[GridViewActions]
--
ALTER TABLE SUserInterface.GridViewActions
  DROP CONSTRAINT IF EXISTS FK_GridViewActions_EntityQueries
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SUserInterface].[GridViewWidgetQueries]
--
ALTER TABLE SUserInterface.GridViewWidgetQueries
  DROP CONSTRAINT IF EXISTS FK_GridViewWidgetQueries_EntityQueries
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[EntityPropertyGroups]
--
ALTER TABLE SCore.EntityPropertyGroups
  DROP CONSTRAINT IF EXISTS FK_EntityPropertyGroups_LanguageLabels
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SCore].[EntityTypes]
--
ALTER TABLE SCore.EntityTypes
  DROP CONSTRAINT IF EXISTS FK_EntityTypes_LanguageLabels
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SUserInterface].[GridDefinitions]
--
ALTER TABLE SUserInterface.GridDefinitions
  DROP CONSTRAINT IF EXISTS FK_GridDefinitions_LanguageLabelId
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Dropping constraints from [SUserInterface].[MainMenuItems]
--
ALTER TABLE SUserInterface.MainMenuItems
  DROP CONSTRAINT IF EXISTS FK_MainMenuItems_LanguageLabelId
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Updating data of table [SCore].[EntityProperties]
--
UPDATE SCore.EntityProperties SET IsIncludedInformation = 1 WHERE ID = 1228
UPDATE SCore.EntityProperties SET SqlDefaultValueStatement = N'SELECT	p.Guid
FROM	SSop.Projects AS p 
WHERE	(p.Guid = ''[[ParentGuid]]'')
UNION ALL 
SELECT	p.Guid
FROM	SSop.Projects AS p 
JOIN	SJob.Jobs AS j ON (j.ProjectId = p.ID)
WHERE	(j.Guid = ''[[ParentGuid]]'')
UNION ALL 
SELECT	p.Guid
FROM	SSop.Projects AS p 
JOIN	SSop.Enquiries AS e ON (e.ProjectId = p.ID)
WHERE	(e.Guid = ''[[ParentGuid]]'')
UNION ALL 
SELECT	p.Guid
FROM	SSop.Projects AS p 
JOIN	SSop.Quotes AS q ON (q.ProjectId = p.ID)
WHERE	(q.Guid = ''[[ParentGuid]]'')' WHERE ID = 1819
UPDATE SCore.EntityProperties SET SqlDefaultValueStatement = N'SELECT	p.Guid
FROM	SSop.Projects AS p 
WHERE	(p.Guid = ''[[ParentGuid]]'')
UNION ALL 
SELECT	p.Guid
FROM	SSop.Projects AS p 
JOIN	SJob.Jobs AS j ON (j.ProjectId = p.ID)
WHERE	(j.Guid = ''[[ParentGuid]]'')
UNION ALL 
SELECT	p.Guid
FROM	SSop.Projects AS p 
JOIN	SSop.Enquiries AS e ON (e.ProjectId = p.ID)
WHERE	(e.Guid = ''[[ParentGuid]]'')
UNION ALL 
SELECT	p.Guid
FROM	SSop.Projects AS p 
JOIN	SSop.Quotes AS q ON (q.ProjectId = p.ID)
WHERE	(q.Guid = ''[[ParentGuid]]'')' WHERE ID = 1822
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Updating data of table [SCore].[EntityQueries]
--
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.ID
,	root_hobt.RowStatus
,	root_hobt.RowVersion
,	root_hobt.Guid
,	root_hobt.Name
,	[E1D97654-B776-4BB6-A913-3A5B2E250685].Guid AS LanguageLabelID
,	[77B88FCE-FCC3-4C92-94E6-CC61249845C3].Guid AS EntityHoBTID
,	[59E622E7-EDA9-4DB3-A4D5-9439D80D26C1].Guid AS EntityDataTypeID
,	root_hobt.IsReadOnly
,	root_hobt.IsImmutable
,	root_hobt.IsUppercase
,	root_hobt.IsHidden
,	root_hobt.IsCompulsory
,	root_hobt.MaxLength
,	root_hobt.Precision
,	root_hobt.Scale
,	root_hobt.DoNotTrackChanges
,	[216CAEF2-7139-41F2-8C27-D5B9B4517B1A].Guid AS EntityPropertyGroupID
,	root_hobt.SortOrder
,	root_hobt.GroupSortOrder
,	root_hobt.IsObjectLabel
,	[C44B8A2A-8C24-41F0-B85E-E163A4D8E555].Guid AS DropDownListDefinitionID
,	root_hobt.IsParentRelationship
,	root_hobt.IsIncludedInformation
,	root_hobt.IsLatitude
,	root_hobt.IsLongitude
,	root_hobt.FixedDefaultValue
,	root_hobt.SqlDefaultValueStatement
,	root_hobt.AllowBulkChange
,	root_hobt.IsVirtual

FROM SCore.EntityProperties AS root_hobt 
JOIN SCore.LanguageLabels AS [E1D97654-B776-4BB6-A913-3A5B2E250685] ON ([E1D97654-B776-4BB6-A913-3A5B2E250685].ID = root_hobt.LanguageLabelID) 
 JOIN SCore.EntityHobts AS [77B88FCE-FCC3-4C92-94E6-CC61249845C3] ON ([77B88FCE-FCC3-4C92-94E6-CC61249845C3].ID = root_hobt.EntityHoBTID) 
 JOIN SCore.EntityDataTypes AS [59E622E7-EDA9-4DB3-A4D5-9439D80D26C1] ON ([59E622E7-EDA9-4DB3-A4D5-9439D80D26C1].ID = root_hobt.EntityDataTypeID) 
 JOIN SCore.EntityPropertyGroups AS [216CAEF2-7139-41F2-8C27-D5B9B4517B1A] ON ([216CAEF2-7139-41F2-8C27-D5B9B4517B1A].ID = root_hobt.EntityPropertyGroupID) 
 JOIN SUserInterface.DropDownListDefinitions AS [C44B8A2A-8C24-41F0-B85E-E163A4D8E555] ON ([C44B8A2A-8C24-41F0-B85E-E163A4D8E555].ID = root_hobt.DropDownListDefinitionID) 
' WHERE ID = 7
UPDATE SCore.EntityQueries SET Statement = N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid, 
		root_hobt.Code, 
		root_hobt.NameColumn,
		root_hobt.ValueColumn,
		root_hobt.SqlQuery,
		root_hobt.DefaultSortColumnName, 
		root_hobt.IsDefaultColumn,
		root_hobt.DetailPageUrl,
		root_hobt.IsDetailWindowed,
        root_hobt.InformationPageUrl, 
        root_hobt.GroupColumn,
		root_hobt.ColourHexColumn,
		et.Guid as EntityTypeId
FROM	SUserInterface.DropDownListDefinitions root_hobt
JOIN	SCore.EntityTypes et ON (et.ID = root_hobt.EntityTypeId)' WHERE ID = 14
UPDATE SCore.EntityQueries SET Statement = N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Name,
        root_hobt.ColumnOrder,
        root_hobt.IsPrimaryKey,
        root_hobt.IsHidden,
        root_hobt.IsFiltered,
        root_hobt.IsCombo,
        root_hobt.IsLongitude,
        root_hobt.IsLatitude,
        root_hobt.DisplayFormat,
        root_hobt.Width,
        ll.Guid AS LanguageLabelId,
        gvd.Guid AS GridViewDefinitionId,
        root_hobt.TopHeaderCategory,
       root_hobt.TopHeaderCategoryOrder
FROM
        SUserInterface.GridViewColumnDefinitions root_hobt
JOIN
        SUserInterface.GridViewDefinitions gvd ON (gvd.ID = root_hobt.GridViewDefinitionId) 
JOIN    SCore.LanguageLabels ll on (root_hobt.LanguageLabelId = ll.ID)' WHERE ID = 17
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SUserInterface].[GridViewDefinitionUpsert]  
	@Code = @Code, 
	@RowStatus = @RowStatus, 
	@GridDefinitionGuid = @GridDefinitionGuid, 
	@DetailPageUri = @DetailPageUri, 
	@SqlQuery = @SqlQuery, 
	@DefaultSortColumnName = @DefaultSortColumnName, 
	@SecurableCode = @SecurableCode, 
	@DisplayOrder = @DisplayOrder, 
	@DisplayGroupName = @DisplayGroupName, 
	@MetricSqlQuery = @MetricSqlQuery, 
	@ShowMetric = @ShowMetric, 
	@IsDetailWindowed = @IsDetailWindowed, 
	@EntityTypeGuid = @EntityTypeGuid, 
	@MetricTypeGuid = @MetricTypeGuid, 
	@MetricMin = @MetricMin, 
	@MetricMax = @MetricMax, 
	@MetricMinorUnit = @MetricMinorUnit, 
	@MetricMajorUnit = @MetricMajorUnit, 
	@MetricStartAngle = @MetricStartAngle, 
	@MetricEndAngle = @MetricEndAngle, 
	@MetricReversed = @MetricReversed, 
	@MetricRange1Min = @MetricRange1Min, 
	@MetricRange1Max = @MetricRange1Max, 
	@MetricRange1ColourHex = @MetricRange1ColourHex, 
	@MetricRange2Min = @MetricRange2Min, 
	@MetricRange2Max = @MetricRange2Max, 
	@MetricRange2ColourHex = @MetricRange2ColourHex, 
	@IsDefaultSortDescending = @IsDefaultSortDescending, 
	@AllowNew = @AllowNew, 
	@AllowExcelExport = @AllowExcelExport, 
	@AllowPdfExport = @AllowPdfExport, 
	@AllowCsvExport = @AllowCsvExport, 
	@LanguageLabelGuid = @LanguageLabelGuid, 
	@DrawerIconGuid = @DrawerIconGuid, 
	@GridViewTypeGuid = @GridViewTypeGuid, 
	@AllowBulkChange = @AllowBulkChange, 
	@Guid = @Guid' WHERE ID = 19
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SUserInterface].[GridViewColumnDefinitionUpsert]
  @Name                   = @Name,
  @RowStatus              = @RowStatus,
  @GridViewDefinitionGuid = @GridViewDefinitionGuid,
  @ColumnOrder            = @ColumnOrder,
  @IsPrimaryKey           = @IsPrimaryKey,
  @IsHidden               = @IsHidden,
  @IsFiltered             = @IsFiltered,
  @IsCombo                = @IsCombo,
  @DisplayFormat          = @DisplayFormat,
  @Width                  = @Width,
  @LanguageLabelGuid      = @LanguageLabelGuid,
  @Guid                   = @Guid,
 @TopHeaderCategory = @TopHeaderCategory,
@TopHeaderCategoryOrder = @TopHeaderCategoryOrder' WHERE ID = 20
UPDATE SCore.EntityQueries SET Statement = N'EXEC SUserInterface.DropDownListDefinitionUpsert @Code = @Code,
												 @NameColumn = @NameColumn,
												 @ValueColumn = @ValueColumn,
												 @SqlQuery = @SqlQuery,
												 @DefaultSortColumnName = @DefaultSortColumnName,
												 @IsDefaultColumn = @IsDefaultColumn,
												 @DetailPageURI = @DetailPageURI,
												 @IsDetailWindowed = @IsDetailWindowed, 
												 @EntityTypeGuid = @EntityTypeGuid,
 												 @InformationPageUri = @InformationPageUri,  
                                                                                                 @GroupColumn = @GroupColumn,
												 @Guid = @Guid,
                                                                                                 @ColourHexColumn = @ColourHexColumn;' WHERE ID = 21
UPDATE SCore.EntityQueries SET Statement = N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.AgreedFee,
        root_hobt.RibaStage1Fee,
        root_hobt.RibaStage2Fee,
        root_hobt.RibaStage3Fee,
        root_hobt.RibaStage4Fee,
        root_hobt.RibaStage5Fee,
        root_hobt.RibaStage6Fee,
        root_hobt.RibaStage7Fee,
        root_hobt.PreConstructionStageFee,
        root_hobt.ConstructionStageFee,
        root_hobt.ArchiveBoxReference,
        root_hobt.ArchiveReferenceLink,
        root_hobt.CreatedOn,
        root_hobt.ExternalReference,
        root_hobt.IsSubjectToNDA,
        root_hobt.JobCancelled,
        root_hobt.JobCompleted,
        root_hobt.JobDescription,
        root_hobt.JobStarted,
		root_hobt.DeadDate,
        root_hobt.Number,
        root_hobt.VersionID,
        root_hobt.IsCompleteForReview,
        root_hobt.ReviewedDateTimeUTC,
        root_hobt.LegacyID,
        root_hobt.AppFormReceived,
        root_hobt.FeeCap,
        root_hobt.JobDormant,
        root_hobt.CurrentRibaStageId,
        root_hobt.JobTypeID,
        root_hobt.SurveyorID,
        root_hobt.CreatedByUserID,
        root_hobt.ClientAccountID,
        root_hobt.ClientAddressID,
        root_hobt.ClientContactID,
        root_hobt.AgentAccountID,
        root_hobt.AgentAddressID,
        root_hobt.AgentContactID,
        root_hobt.FinanceAccountID,
        root_hobt.FinanceAddressID,
        root_hobt.FinanceContactID,
        root_hobt.OrganisationalUnitID,
        root_hobt.QuoteItemID,
        root_hobt.UprnID,
        root_hobt.ValueOfWorkID,
        root_hobt.ReviewedByUserID,
        root_hobt.ContractID,
        root_hobt.PurchaseOrderNumber,
        root_hobt.ProjectId,
        root_hobt.ValueOfWork,
        root_hobt.ClientAppointmentReceived,
	root_hobt.AppointedFromStageId,
        root_hobt.BillingInstruction
FROM
        SJob.Jobs_Read AS root_hobt' WHERE ID = 30
UPDATE SCore.EntityQueries SET Statement = N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.Code,
		root_hobt.IsPurchaseLedger,
		root_hobt.IsSalesLedger,
		root_hobt.IsLocalAuthority,
		root_hobt.IsFireAuthority,
		root_hobt.IsWaterAuthority,
		root_hobt.CompanyRegistrationNumber,
		root_hobt.LegacyID,
		s.Guid	AS AccountStatusID,
		pa.Guid AS ParentAccountID,
		rmi.Guid AS RelationshipManagerUserId,
		ac.Guid AS MainAccountContactId,
		aa.Guid AS MainAccountAddressId,
        root_hobt.BillingInstruction,
		root_hobt.ConcatenatedNameCode
FROM	SCrm.Accounts	   AS root_hobt
JOIN	SCrm.AccountStatus AS s ON (s.ID   = root_hobt.AccountStatusID)
JOIN	SCrm.Accounts	   AS pa ON (pa.ID = root_hobt.ParentAccountID)
JOIN	Score.Identities AS rmi ON (rmi.ID = root_hobt.RelationshipManagerUserId)
JOIN	SCrm.AccountContacts ac ON (ac.ID = root_hobt.MainAccountContactId)
JOIN	SCrm.AccountAddresses aa ON (aa.ID = root_hobt.MainAccountAddressId)' WHERE ID = 39
UPDATE SCore.EntityQueries SET Statement = N'EXEC SCrm.AccountsUpsert @Name = @Name,							-- nvarchar(250)
						 @Code = @Code,							-- nvarchar(10)
						 @AccountStatusGuid = @AccountStatusGuid,				-- uniqueidentifier
						 @ParentAccountGuid = @ParentAccountGuid,				-- uniqueidentifier
						 @IsPurchaseLedger = @IsPurchaseLedger,				-- bit
						 @IsSalesLedger = @IsSalesLedger,					-- bit
						 @IsLocalAuthority = @IsLocalAuthority,				-- bit
						 @IsFireAuthority = @IsFireAuthority,				-- bit
						 @IsWaterAuthority = @IsWaterAuthority,				-- bit
						 @RelationshipManagerUserGuid = @RelationshipManagerUserGuid,	-- uniqueidentifier
						 @CompanyRegistrationNumber = @CompanyRegistrationNumber,		-- nvarchar(50)
						 @MainAccountAddressGuid = @MainAccountAddressGuid,
						 @MainAccountContactGuid = @MainAccountContactGuid,
						 @Guid = @Guid,							-- uniqueidentifier 
                                                  @BillingInstruction = @BillingInstruction' WHERE ID = 45
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.Guid
,	[DFBC2B7E-9655-44D7-966E-E749E7F702AA].Guid AS JobID
,	[59D35AD9-A62C-417B-AE34-255C0FA2E3D5].Guid AS AccountID
,	root_hobt.RowVersion
,	root_hobt.RowStatus
,	root_hobt.ID
,	[9D0F7D88-097A-43BF-B667-2C58F8E7AAA3].Guid AS ProjectDirectoryRoleID
,	[9A444DB8-F290-4443-BAC6-D77999EA1DD9].Guid AS ContactID
,	[DED3069E-FA1A-4DD6-8EDC-0C2924215B54].Guid AS ProjectID

FROM SJob.ProjectDirectory AS root_hobt 
JOIN SJob.Jobs AS [DFBC2B7E-9655-44D7-966E-E749E7F702AA] ON ([DFBC2B7E-9655-44D7-966E-E749E7F702AA].ID = root_hobt.JobID) 
 JOIN SCrm.Accounts AS [59D35AD9-A62C-417B-AE34-255C0FA2E3D5] ON ([59D35AD9-A62C-417B-AE34-255C0FA2E3D5].ID = root_hobt.AccountID) 
 JOIN SJob.ProjectDirectoryRoles AS [9D0F7D88-097A-43BF-B667-2C58F8E7AAA3] ON ([9D0F7D88-097A-43BF-B667-2C58F8E7AAA3].ID = root_hobt.ProjectDirectoryRoleID) 
 JOIN SCrm.Contacts AS [9A444DB8-F290-4443-BAC6-D77999EA1DD9] ON ([9A444DB8-F290-4443-BAC6-D77999EA1DD9].ID = root_hobt.ContactID) 
 JOIN SSop.Projects AS [DED3069E-FA1A-4DD6-8EDC-0C2924215B54] ON ([DED3069E-FA1A-4DD6-8EDC-0C2924215B54].ID = root_hobt.ProjectID) 
' WHERE ID = 65
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SJob].[JobsUpsert]  
	@OrganisationalUnitGuid = @OrganisationalUnitGuid, 
	@JobTypeGuid = @JobTypeGuid, 
	@UprnGuid = @UprnGuid, 
	@ClientAccountGuid = @ClientAccountGuid, 
	@ClientAddressGuid = @ClientAddressGuid, 
	@ClientContactGuid = @ClientContactGuid, 
	@AgentAccountGuid = @AgentAccountGuid, 
	@AgentAddressGuid = @AgentAddressGuid, 
	@AgentContactGuid = @AgentContactGuid, 
	@FinanceAccountGuid = @FinanceAccountGuid, 
	@FinanceAddressGuid = @FinanceAddressGuid, 
	@FinanceContactGuid = @FinanceContactGuid, 
	@SurveyorGuid = @SurveyorGuid, 
	@JobDescription = @JobDescription, 
	@IsSubjectToNDA = @IsSubjectToNDA, 
	@JobStarted = @JobStarted, 
	@JobCompleted = @JobCompleted, 
	@JobCancelled = @JobCancelled, 
	@ValueOfWorkGuid = @ValueOfWorkGuid, 
	@AgreedFee = @AgreedFee, 
	@RibaStage1Fee = @RibaStage1Fee, 
	@RibaStage2Fee = @RibaStage2Fee, 
	@RibaStage3Fee = @RibaStage3Fee, 
	@RibaStage4Fee = @RibaStage4Fee, 
	@RibaStage5Fee = @RibaStage5Fee, 
	@RibaStage6Fee = @RibaStage6Fee, 
	@RibaStage7Fee = @RibaStage7Fee, 
	@PreConstructionStageFee = @PreConstructionStageFee, 
	@ConstructionStageFee = @ConstructionStageFee, 
	@ArchiveReferenceLink = @ArchiveReferenceLink, 
	@ArchiveBoxReference = @ArchiveBoxReference, 
	@CreatedOn = @CreatedOn, 
	@ExternalReference = @ExternalReference, 
	@IsCompleteForReview = @IsCompleteForReview, 
	@ReviewedByUserGuid = @ReviewedByUserGuid, 
	@ReviewDateTimeUTC = @ReviewDateTimeUTC, 
	@AppFormReceived = @AppFormReceived, 
	@FeeCap = @FeeCap, 
	@CurrentRibaStageGuid = @CurrentRibaStageGuid, 
	@JobDormant = @JobDormant, 
	@PurchaseOrderNumber = @PurchaseOrderNumber, 
	@ContractGuid = @ContractGuid, 
	@ProjectGuid = @ProjectGuid, 
	@ValueOfWork = @ValueOfWork, 
	@ClientAppointmentReceived = @ClientAppointmentReceived, 
	@AppointedFromStageGuid = @AppointedFromStageGuid, 
	@DeadDate = @DeadDate, 
	@Guid = @Guid, 
	@BillingInstruction = @BillingInstruction' WHERE ID = 67
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	[01FDD623-FA79-43E2-AC7B-FA45BEF7FC73].Guid AS ClientAddressId
,	[04DD32E8-AE80-4F81-BD9A-F646441AFBE4].Guid AS ClientContactId
,	[F530931A-6E91-4BEB-BF2C-4C48B58C07D9].Guid AS ContractID
,	root_hobt.Date
,	root_hobt.Guid
,	root_hobt.ID
,	root_hobt.Number
,	[07C15164-1D8B-452D-9CEC-EEF64056AB52].Guid AS OrganisationalUnitID
,	root_hobt.Overview
,	[EE947786-1E4A-40D8-B0AD-E2D0B039CF6E].Guid AS QuotingUserId
,	root_hobt.RowStatus
,	root_hobt.RowVersion
,	root_hobt.DateAccepted
,	root_hobt.DateRejected
,	root_hobt.DateSent
,	root_hobt.ExpiryDate
,	[3AFE632D-2EE2-4FD8-8FFC-E696E84E095C].Guid AS QuoteSourceId
,	root_hobt.RejectionReason
,	[3FDEF099-DBC8-4F1D-B8D7-529600A0B62D].Guid AS AgentAddressId
,	[5AA9C5DF-307E-4DEE-9EE0-7B97115E1315].Guid AS AgentContactId
,	root_hobt.ExternalReference
,	root_hobt.IsSubjectToNDA
,	root_hobt.ChaseDate1
,	root_hobt.ChaseDate2
,	root_hobt.FeeCap
,	root_hobt.IsFinal
,	root_hobt.LegacyId
,	root_hobt.SendInfoToAgent
,	root_hobt.SendInfoToClient
,	[7E3459EE-8083-4C0E-9652-03D71A98F857].Guid AS QuotingConsultantId
,	[FC51FD71-51A1-4B7A-BA50-F0C2F2816225].Guid AS AppointmentFromRibaStageId
,	[DA716B55-56FA-40CE-B1E3-50A56F2F233A].Guid AS ProjectId
,	root_hobt.ValueOfWork
,	[34B965DC-8D1F-4066-81BB-852157CBB00F].Guid AS OriginalQuoteId
,	root_hobt.RevisionNumber
,	[93001C06-FD4A-4965-B8EA-EDAF8C16A21E].Guid AS CurrentRibaStageId
,	root_hobt.DeadDate
,	[30E87213-B425-43FC-B37C-6F1F3EDE3AE0].Guid AS EnquiryServiceID
,	root_hobt.ExclusionsAndLimitations
,	root_hobt.LegacySystemID
,       root_hobt.DateDeclinedToQuote
,      root_hobt.DeclinedToQuoteReason


FROM SSop.Quotes AS root_hobt 
JOIN SCrm.AccountAddresses AS [01FDD623-FA79-43E2-AC7B-FA45BEF7FC73] ON ([01FDD623-FA79-43E2-AC7B-FA45BEF7FC73].ID = root_hobt.ClientAddressId) 
 JOIN SCrm.AccountContacts AS [04DD32E8-AE80-4F81-BD9A-F646441AFBE4] ON ([04DD32E8-AE80-4F81-BD9A-F646441AFBE4].ID = root_hobt.ClientContactId) 
 JOIN SSop.Contracts AS [F530931A-6E91-4BEB-BF2C-4C48B58C07D9] ON ([F530931A-6E91-4BEB-BF2C-4C48B58C07D9].ID = root_hobt.ContractID) 
 JOIN SCore.OrganisationalUnits AS [07C15164-1D8B-452D-9CEC-EEF64056AB52] ON ([07C15164-1D8B-452D-9CEC-EEF64056AB52].ID = root_hobt.OrganisationalUnitID) 
 JOIN SCore.Identities AS [EE947786-1E4A-40D8-B0AD-E2D0B039CF6E] ON ([EE947786-1E4A-40D8-B0AD-E2D0B039CF6E].ID = root_hobt.QuotingUserId) 
 JOIN SSop.QuoteSources AS [3AFE632D-2EE2-4FD8-8FFC-E696E84E095C] ON ([3AFE632D-2EE2-4FD8-8FFC-E696E84E095C].ID = root_hobt.QuoteSourceId) 
 JOIN SCrm.AccountAddresses AS [3FDEF099-DBC8-4F1D-B8D7-529600A0B62D] ON ([3FDEF099-DBC8-4F1D-B8D7-529600A0B62D].ID = root_hobt.AgentAddressId) 
 JOIN SCrm.AccountContacts AS [5AA9C5DF-307E-4DEE-9EE0-7B97115E1315] ON ([5AA9C5DF-307E-4DEE-9EE0-7B97115E1315].ID = root_hobt.AgentContactId) 
 JOIN SCore.Identities AS [7E3459EE-8083-4C0E-9652-03D71A98F857] ON ([7E3459EE-8083-4C0E-9652-03D71A98F857].ID = root_hobt.QuotingConsultantId) 
 JOIN SJob.RibaStages AS [FC51FD71-51A1-4B7A-BA50-F0C2F2816225] ON ([FC51FD71-51A1-4B7A-BA50-F0C2F2816225].ID = root_hobt.AppointmentFromRibaStageId) 
 JOIN SSop.Projects AS [DA716B55-56FA-40CE-B1E3-50A56F2F233A] ON ([DA716B55-56FA-40CE-B1E3-50A56F2F233A].ID = root_hobt.ProjectId) 
 JOIN SSop.Quotes AS [34B965DC-8D1F-4066-81BB-852157CBB00F] ON ([34B965DC-8D1F-4066-81BB-852157CBB00F].ID = root_hobt.OriginalQuoteId) 
 JOIN SJob.RibaStages AS [93001C06-FD4A-4965-B8EA-EDAF8C16A21E] ON ([93001C06-FD4A-4965-B8EA-EDAF8C16A21E].ID = root_hobt.CurrentRibaStageId) 
 JOIN SSop.EnquiryServices AS [30E87213-B425-43FC-B37C-6F1F3EDE3AE0] ON ([30E87213-B425-43FC-B37C-6F1F3EDE3AE0].ID = root_hobt.EnquiryServiceID) 
' WHERE ID = 82
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SSop].[QuotesUpsert]  
	@OrganisationalUnitGuid = @OrganisationalUnitGuid, 
	@QuotingUserGuid = @QuotingUserGuid, 
	@ContractGuid = @ContractGuid, 
	@Date = @Date, 
	@Overview = @Overview, 
	@ExpiryDate = @ExpiryDate, 
	@DateSent = @DateSent, 
	@DateAccepted = @DateAccepted, 
	@DateRejected = @DateRejected, 
	@RejectionReason = @RejectionReason, 
	@FeeCap = @FeeCap, 
	@IsFinal = @IsFinal, 
	@ExternalReference = @ExternalReference, 
	@QuotingConsultantGuid = @QuotingConsultantGuid, 
	@AppointmentFromRibaStageGuid = @AppointmentFromRibaStageGuid, 
	@CurrentStageGuid = @CurrentStageGuid, 
	@DeadDate = @DeadDate, 
	@EnquiryServiceGuid = @EnquiryServiceGuid, 
	@ProjectGuid = @ProjectGuid, 
	@Guid = @Guid, 
	@JobType = @JobType, 
	@DeclinedToQuoteReason = @DeclinedToQuoteReason, 
	@DescriptionOfWorks = @DescriptionOfWorks, 
	@ExclusionsAndLimitations = @ExclusionsAndLimitations' WHERE ID = 85
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	[A47D9C7E-9DCA-4AE0-B3AD-73A0690EDD92].Guid AS CreatedJobId,
	root_hobt.Details,
	root_hobt.DoNotConsolidateJob,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.LegacyId,
	root_hobt.LegacySystemID,
	root_hobt.Net,
	[6BA255D5-2339-4286-A86C-494A2AB1DA4A].Guid AS ProductId,
	[6E8FD1FD-157F-4B88-80CD-C0589CAD9D2A].Guid AS ProvideAtStageID,
	root_hobt.Quantity,
	[7EC6389A-C5BA-4B84-BE24-096C86DF6770].Guid AS QuoteId,
	[EEA4BD07-8A21-4B1B-8050-819EA27E1B11].Guid AS QuoteSectionId,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SortOrder,
	root_hobt.VatRate,
        root_hobt.NumberOfSiteVisits,
        root_hobt.NumberOfMeetings
FROM SSop.QuoteItems AS root_hobt 
JOIN SProd.Products AS [6BA255D5-2339-4286-A86C-494A2AB1DA4A] ON ([6BA255D5-2339-4286-A86C-494A2AB1DA4A].ID = root_hobt.ProductId) 
 JOIN SSop.QuoteSections AS [EEA4BD07-8A21-4B1B-8050-819EA27E1B11] ON ([EEA4BD07-8A21-4B1B-8050-819EA27E1B11].ID = root_hobt.QuoteSectionId) 
 JOIN SJob.Jobs AS [A47D9C7E-9DCA-4AE0-B3AD-73A0690EDD92] ON ([A47D9C7E-9DCA-4AE0-B3AD-73A0690EDD92].ID = root_hobt.CreatedJobId) 
 JOIN SJob.RibaStages AS [6E8FD1FD-157F-4B88-80CD-C0589CAD9D2A] ON ([6E8FD1FD-157F-4B88-80CD-C0589CAD9D2A].ID = root_hobt.ProvideAtStageID) 
 JOIN SSop.Quotes AS [7EC6389A-C5BA-4B84-BE24-096C86DF6770] ON ([7EC6389A-C5BA-4B84-BE24-096C86DF6770].ID = root_hobt.QuoteId) 
' WHERE ID = 87
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SSop].[QuoteItemsUpsert]  
	@QuoteGuid = @QuoteGuid, 
	@ProductGuid = @ProductGuid, 
	@Details = @Details, 
	@Net = @Net, 
	@VatRate = @VatRate, 
	@DoNotConsolidateJob = @DoNotConsolidateJob, 
	@SortOrder = @SortOrder, 
	@Quantity = @Quantity, 
	@ProvidedAtStageGuid = @ProvidedAtStageGuid, 
	@Guid = @Guid,
        @NumberOfSiteVisits = @NumberOfSiteVisits,
        @NumberOfMeetings = @NumberOfMeetings' WHERE ID = 91
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SJob].[ActivityTypesUpsert]  
	@Name = @Name, 
	@IsActive = @IsActive, 
	@SortOrder = @SortOrder, 
	@IsFeeTrigger = @IsFeeTrigger, 
	@IsLiveTrigger = @IsLiveTrigger, 
	@IsAdmin = @IsAdmin, 
	@IsScheduleItem = @IsScheduleItem, 
	@Colour = @Colour, 
	@IsMeeting = @IsMeeting, 
	@IsSiteVisit = @IsSiteVisit, 
	@IsCommencementTrigger = @IsCommencementTrigger, 
	@Guid = @Guid, 
	@IsBillable = @IsBillable' WHERE ID = 109
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.IsActive,
	root_hobt.Name,
	[8C9FF97B-D7E8-4BF2-A153-ED7D08A9787A].Guid AS OrganisationalUnitID,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SequenceID,
	root_hobt.UsePlanChecks,
	root_hobt.UseTimeSheets
FROM SJob.JobTypes AS root_hobt 
JOIN SCore.OrganisationalUnits AS [8C9FF97B-D7E8-4BF2-A153-ED7D08A9787A] ON ([8C9FF97B-D7E8-4BF2-A153-ED7D08A9787A].ID = root_hobt.OrganisationalUnitID) 
' WHERE ID = 122
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SCore].[MergeDocumentsUpsert]  
	@Name = @Name, 
	@FilenameTemplate = @FilenameTemplate, 
	@EntityTypeGuid = @EntityTypeGuid, 
	@SharepointSiteGuid = @SharepointSiteGuid, 
	@DocumentId = @DocumentId, 
	@LinkedEntityTypeGuid = @LinkedEntityTypeGuid, 
	@AllowPDFOutputOnly = @AllowPDFOutputOnly, 
	@AllowExcelOutputOnly = @AllowExcelOutputOnly, 
	@ProduceOneOutputPerRow = @ProduceOneOutputPerRow, 
	@Guid = @Guid' WHERE ID = 123
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.AllowPDFOutputOnly,
        root_hobt.AllowExcelOutputOnly,
	root_hobt.DocumentId,
	[2F88C3FF-B564-4B42-84BA-8B527EBABED6].Guid AS EntityTypeId,
	root_hobt.FilenameTemplate,
	root_hobt.Guid,
	root_hobt.ID,
	[FEFEFAA1-DFB4-49FD-BBF6-563AE47DF1C0].Guid AS LinkedEntityTypeId,
	root_hobt.Name,
	root_hobt.ProduceOneOutputPerRow,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	[6551966B-1294-437E-8E20-E9771C9F2D1E].Guid AS SharepointSiteId
FROM SCore.MergeDocuments AS root_hobt 
JOIN SCore.EntityTypes AS [2F88C3FF-B564-4B42-84BA-8B527EBABED6] ON ([2F88C3FF-B564-4B42-84BA-8B527EBABED6].ID = root_hobt.EntityTypeId) 
 JOIN SCore.EntityTypes AS [FEFEFAA1-DFB4-49FD-BBF6-563AE47DF1C0] ON ([FEFEFAA1-DFB4-49FD-BBF6-563AE47DF1C0].ID = root_hobt.LinkedEntityTypeId) 
 JOIN SCore.SharepointSites AS [6551966B-1294-437E-8E20-E9771C9F2D1E] ON ([6551966B-1294-437E-8E20-E9771C9F2D1E].ID = root_hobt.SharepointSiteId) 
' WHERE ID = 125
EXEC(N'UPDATE SCore.EntityQueries SET Statement = N''SELECT 
	[62A7CA41-57FE-4541-9B7B-64C2BECBD403].Guid AS AgentAccountContactId,
	[C6D3628B-9EF6-46E7-A04B-455D7256E180].Guid AS AgentAccountId,
	[518A2AAD-697B-4134-B39D-20C20B5FCD92].Guid AS AgentAddressId,
	root_hobt.AgentAddressLine1,
	root_hobt.AgentAddressLine2,
	root_hobt.AgentAddressLine3,
	root_hobt.AgentAddressNameNumber,
	root_hobt.AgentAddressPostCode,
	[9B125B55-B220-4023-AA54-BABCDF6AFD1B].Guid AS AgentCountryId,
	[7EA7CAB9-F5BC-4B00-AE06-276E3B772910].Guid AS AgentCountyId,
	root_hobt.AgentName,
	root_hobt.AgentTown,
	root_hobt.ChaseDate1,
	root_hobt.ChaseDate2,
	[CCDDA156-B2D7-4F37-AA9E-1CB98F3C11FD].Guid AS ClientAccountContactId,
	[C1AFB8A2-4596-4C64-8267-7F49B9BE04D6].Guid AS ClientAccountId,
	[3611CED8-53C2-4FA8-9ACC-F508149BC716].Guid AS ClientAddressCountryId,
	[A0DB71C1-2E2B-4559-95E4-9CEBF2F01BA5].Guid AS ClientAddressCountyId,
	[8D6A7C6A-9D55-4C03-82F1-75B6BB5BB3CC].Guid AS ClientAddressId,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientAddressNameNumber,
	root_hobt.ClientAddressPostCode,
	root_hobt.ClientAddressTown,
	root_hobt.ClientName,
	root_hobt.ConstructionStageMonths,
	[2B074135-3D54-49A9-ACDE-C82FDB5F9067].Guid AS CreatedByUserId,
	[D020A007-8E39-450B-8575-69D76529659A].Guid AS CurrentProjectRibaStageID,
	root_hobt.Date,
	root_hobt.DeadDate,
	root_hobt.DeclinedToQuoteDate,
	root_hobt.DeclinedToQuoteReason,
	root_hobt.DescriptionOfWorks,
	[DE5A2964-7F7D-4194-962C-11F3FA18DB55].Guid AS EnquirySourceId,
	root_hobt.EnterNewAgentDetails,
	root_hobt.EnterNewClientDetails,
	root_hobt.EnterNewFinanceDetails,
	root_hobt.EnterNewStructureDetails,
	root_hobt.ExpectedProcurementRoute,
	root_hobt.ExternalReference,
	[B7C58113-E763-4B52-82D5-21501514AF8C].Guid AS FinanceAccountId,
	root_hobt.FinanceAccountName,
	[BC7CF205-B05B-41AC-B0CC-E23AEDC459D8].Guid AS FinanceAddressId,
	root_hobt.FinanceAddressLine1,
	root_hobt.FinanceAddressLine2,
	root_hobt.FinanceAddressLine3,
	root_hobt.FinanceAddressNameNumber,
	[02B19759-9D35-447C-9AE2-3C7B9027FEB1].Guid AS FinanceContactId,
	[70FEA0EA-C279-484C-931D-2D23F42D01C3].Guid AS FinanceCountyId,
	root_hobt.FinancePostCode,
	root_hobt.FinanceTown,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.IsClientFinanceAccount,
	root_hobt.IsReadyForQuoteReview,
	root_hobt.IsSubjectToNDA,
	root_hobt.KeyDates,
	root_hobt.Notes,
	root_hobt.Number,
	[1C4B6562-A512-4FC9-85EE-F6A2193EBECE].Guid AS OrganisationalUnitID,
	root_hobt.PreConstructionStageMonths,
	[9066A2DA-692E-4EFD-A2F0-FF124E2F366E].Guid AS ProjectId,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	[C1B43942-F1B0-42DD-8AB7-E1D2C02DFA1B].Guid AS PropertyCountryId,
	[EF3E7956-4ECB-49B0-B930-8DB68D545FFB].Guid AS PropertyCountyId,
	[FE002E4D-3B56-499F-93DA-5D43259CBC76].Guid AS PropertyId,
	root_hobt.PropertyNameNumber,
	root_hobt.PropertyPostCode,
	root_hobt.PropertyTown,
	root_hobt.ProposalLetter,
	root_hobt.QuotingDeadlineDate,
	root_hobt.RibaStage0Months,
	root_hobt.RibaStage1Months,
	root_hobt.RibaStage2Months,
	root_hobt.RibaStage3Months,
	root_hobt.RibaStage4Months,
	root_hobt.RibaStage5Months,
	root_hobt.RibaStage6Months,
	root_hobt.RibaStage7Months,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SendInfoToAgent,
	root_hobt.SendInfoToClient,
	[9264744B-5F58-461B-953B-0C16D80B8FC7].Guid AS SignatoryIdentityId,
	root_hobt.ValueOfWork
FROM SSop.Enquiries AS root_hobt 
JOIN SCrm.Accounts AS [C6D3628B-9EF6-46E7-A04B-455D7256E180] ON ([C6D3628B-9EF6-46E7-A04B-455D7256E180].ID = root_hobt.AgentAccountId) 
 JOIN SCrm.AccountAddresses AS [518A2AAD-697B-4134-B39D-20C20B5FCD92] ON ([518A2AAD-697B-4134-B39D-20C20B5FCD92].ID = root_hobt.AgentAddressId) 
 JOIN SCrm.Countries AS [9B125B55-B220-4023-AA54-BABCDF6AFD1B] ON ([9B125B55-B220-4023-AA54-BABCDF6AFD1B].ID = root_hobt.AgentCountryId) 
 JOIN SCrm.Counties AS [7EA7CAB9-F5BC-4B00-AE06-276E3B772910] ON ([7EA7CAB9-F5B'
+ N'C-4B00-AE06-276E3B772910].ID = root_hobt.AgentCountyId) 
 JOIN SCrm.Accounts AS [C1AFB8A2-4596-4C64-8267-7F49B9BE04D6] ON ([C1AFB8A2-4596-4C64-8267-7F49B9BE04D6].ID = root_hobt.ClientAccountId) 
 JOIN SCrm.Countries AS [3611CED8-53C2-4FA8-9ACC-F508149BC716] ON ([3611CED8-53C2-4FA8-9ACC-F508149BC716].ID = root_hobt.ClientAddressCountryId) 
 JOIN SCrm.Counties AS [A0DB71C1-2E2B-4559-95E4-9CEBF2F01BA5] ON ([A0DB71C1-2E2B-4559-95E4-9CEBF2F01BA5].ID = root_hobt.ClientAddressCountyId) 
 JOIN SCrm.AccountAddresses AS [8D6A7C6A-9D55-4C03-82F1-75B6BB5BB3CC] ON ([8D6A7C6A-9D55-4C03-82F1-75B6BB5BB3CC].ID = root_hobt.ClientAddressId) 
 JOIN SCore.Identities AS [2B074135-3D54-49A9-ACDE-C82FDB5F9067] ON ([2B074135-3D54-49A9-ACDE-C82FDB5F9067].ID = root_hobt.CreatedByUserId) 
 JOIN SJob.RibaStages AS [D020A007-8E39-450B-8575-69D76529659A] ON ([D020A007-8E39-450B-8575-69D76529659A].ID = root_hobt.CurrentProjectRibaStageID) 
 JOIN SCore.OrganisationalUnits AS [1C4B6562-A512-4FC9-85EE-F6A2193EBECE] ON ([1C4B6562-A512-4FC9-85EE-F6A2193EBECE].ID = root_hobt.OrganisationalUnitID) 
 JOIN SCrm.Countries AS [C1B43942-F1B0-42DD-8AB7-E1D2C02DFA1B] ON ([C1B43942-F1B0-42DD-8AB7-E1D2C02DFA1B].ID = root_hobt.PropertyCountryId) 
 JOIN SCrm.Counties AS [EF3E7956-4ECB-49B0-B930-8DB68D545FFB] ON ([EF3E7956-4ECB-49B0-B930-8DB68D545FFB].ID = root_hobt.PropertyCountyId) 
 JOIN SJob.Properties AS [FE002E4D-3B56-499F-93DA-5D43259CBC76] ON ([FE002E4D-3B56-499F-93DA-5D43259CBC76].ID = root_hobt.PropertyId) 
 JOIN SSop.QuoteSources AS [DE5A2964-7F7D-4194-962C-11F3FA18DB55] ON ([DE5A2964-7F7D-4194-962C-11F3FA18DB55].ID = root_hobt.EnquirySourceId) 
 JOIN SCrm.AccountContacts AS [62A7CA41-57FE-4541-9B7B-64C2BECBD403] ON ([62A7CA41-57FE-4541-9B7B-64C2BECBD403].ID = root_hobt.AgentAccountContactId) 
 JOIN SCrm.AccountContacts AS [CCDDA156-B2D7-4F37-AA9E-1CB98F3C11FD] ON ([CCDDA156-B2D7-4F37-AA9E-1CB98F3C11FD].ID = root_hobt.ClientAccountContactId) 
 JOIN SSop.Projects AS [9066A2DA-692E-4EFD-A2F0-FF124E2F366E] ON ([9066A2DA-692E-4EFD-A2F0-FF124E2F366E].ID = root_hobt.ProjectId) 
 JOIN SCrm.Accounts AS [B7C58113-E763-4B52-82D5-21501514AF8C] ON ([B7C58113-E763-4B52-82D5-21501514AF8C].ID = root_hobt.FinanceAccountId) 
 JOIN SCrm.AccountAddresses AS [BC7CF205-B05B-41AC-B0CC-E23AEDC459D8] ON ([BC7CF205-B05B-41AC-B0CC-E23AEDC459D8].ID = root_hobt.FinanceAddressId) 
 JOIN SCrm.AccountContacts AS [02B19759-9D35-447C-9AE2-3C7B9027FEB1] ON ([02B19759-9D35-447C-9AE2-3C7B9027FEB1].ID = root_hobt.FinanceContactId) 
 JOIN SCrm.Counties AS [70FEA0EA-C279-484C-931D-2D23F42D01C3] ON ([70FEA0EA-C279-484C-931D-2D23F42D01C3].ID = root_hobt.FinanceCountyId) 
 JOIN SCore.Identities AS [9264744B-5F58-461B-953B-0C16D80B8FC7] ON ([9264744B-5F58-461B-953B-0C16D80B8FC7].ID = root_hobt.SignatoryIdentityId) 
'' WHERE ID = 159')
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SSop].[EnquiriesUpsert]  
	@OrganisationalUnitGuid = @OrganisationalUnitGuid, 
	@Date = @Date, 
	@CreatedByUserGuid = @CreatedByUserGuid, 
	@PropertyGuid = @PropertyGuid, 
	@PropertyNameNumber = @PropertyNameNumber, 
	@PropertyAddressLine1 = @PropertyAddressLine1, 
	@PropertyAddressLine2 = @PropertyAddressLine2, 
	@PropertyAddressLine3 = @PropertyAddressLine3, 
	@PropertyCountyGuid = @PropertyCountyGuid, 
	@PropertyPostCode = @PropertyPostCode, 
	@PropertyCountryGuid = @PropertyCountryGuid, 
	@ClientAccountGuid = @ClientAccountGuid, 
	@ClientAddressGuid = @ClientAddressGuid, 
	@ClientAccountContactGuid = @ClientAccountContactGuid, 
	@ClientName = @ClientName, 
	@ClientAddressNameNumber = @ClientAddressNameNumber, 
	@ClientAddressLine1 = @ClientAddressLine1, 
	@ClientAddressLine2 = @ClientAddressLine2, 
	@ClientAddressLine3 = @ClientAddressLine3, 
	@ClientAddressCountyGuid = @ClientAddressCountyGuid, 
	@ClientAddressPostCode = @ClientAddressPostCode, 
	@ClientAddressCountryGuid = @ClientAddressCountryGuid, 
	@AgentAccountGuid = @AgentAccountGuid, 
	@AgentAddressGuid = @AgentAddressGuid, 
	@AgentAccountContactGuid = @AgentAccountContactGuid, 
	@AgentName = @AgentName, 
	@AgentAddressNameNumber = @AgentAddressNameNumber, 
	@AgentAddressLine1 = @AgentAddressLine1, 
	@AgentAddressLine2 = @AgentAddressLine2, 
	@AgentAddressLine3 = @AgentAddressLine3, 
	@AgentAddressCountyGuid = @AgentAddressCountyGuid, 
	@AgentAddressPostCode = @AgentAddressPostCode, 
	@AgentAddressCountryGuid = @AgentAddressCountryGuid, 
	@DescriptionOfWorks = @DescriptionOfWorks, 
	@ValueOfWork = @ValueOfWork, 
	@CurrentProjectRobaStageGuid = @CurrentProjectRobaStageGuid, 
	@RibaStage0Months = @RibaStage0Months, 
	@RibaStage1Months = @RibaStage1Months, 
	@RibaStage2Months = @RibaStage2Months, 
	@RibaStage3Months = @RibaStage3Months, 
	@RibaStage4Months = @RibaStage4Months, 
	@RibaStage5Months = @RibaStage5Months, 
	@RibaStage6Months = @RibaStage6Months, 
	@RibaStage7Months = @RibaStage7Months, 
	@PreConstructionStageMonths = @PreConstructionStageMonths, 
	@ConstructionStageMonths = @ConstructionStageMonths, 
	@SendInfoToClient = @SendInfoToClient, 
	@SendInfoToAgent = @SendInfoToAgent, 
	@KeyDates = @KeyDates, 
	@ExpectedProcurementRoute = @ExpectedProcurementRoute, 
	@Notes = @Notes, 
	@EnquirySourceGuid = @EnquirySourceGuid, 
	@IsReadyForQuoteReview = @IsReadyForQuoteReview, 
	@QuotingDeadlineDate = @QuotingDeadlineDate, 
	@DeclinedToQuoteDate = @DeclinedToQuoteDate, 
	@DeclinedToQuoteReason = @DeclinedToQuoteReason, 
	@ExternalReference = @ExternalReference, 
	@ProjectGuid = @ProjectGuid, 
	@IsSubjectToNDA = @IsSubjectToNDA, 
	@DeadDate = @DeadDate, 
	@ChaseDate1 = @ChaseDate1, 
	@ChaseDate2 = @ChaseDate2, 
	@FinanceAccountGuid = @FinanceAccountGuid, 
	@FinanceAddressGuid = @FinanceAddressGuid, 
	@FinanceContactGuid = @FinanceContactGuid, 
	@FinanceAccountName = @FinanceAccountName, 
	@FinanceAddressNameNumber = @FinanceAddressNameNumber, 
	@FinanceAddressLine1 = @FinanceAddressLine1, 
	@FinanceAddressLine2 = @FinanceAddressLine2, 
	@FinanceAddressLine3 = @FinanceAddressLine3, 
	@FinanceCountyGuid = @FinanceCountyGuid, 
	@FinancePostCode = @FinancePostCode, 
	@EnterNewClientDetails = @EnterNewClientDetails, 
	@EnterNewAgentDetails = @EnterNewAgentDetails, 
	@EnterNewFinanceDetails = @EnterNewFinanceDetails, 
	@EnterNewStructureDetails = @EnterNewStructureDetails, 
	@IsClientFinanceAccount = @IsClientFinanceAccount, 
	@SignatoryIdentityGuid = @SignatoryIdentityGuid, 
	@ProposalLetter = @ProposalLetter, 
	@Guid = @Guid' WHERE ID = 160
UPDATE SCore.EntityQueries SET Statement = N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.FullName,
        root_hobt.EmailAddress,
        root_hobt.UserGuid,
        root_hobt.JobTitle,
        root_hobt.IsActive,
        root_hobt.BillableRate,
        root_hobt.Signature,
        ou.Guid AS OriganisationalUnitId,
        c.Guid  AS ContactId
FROM
        SCore.Identities root_hobt
JOIN
        SCore.OrganisationalUnits ou ON (ou.ID = root_hobt.OriganisationalUnitId)
JOIN
        SCrm.Contacts c ON root_hobt.ContactId = c.ID' WHERE ID = 163
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	[8AA3EE8C-0AA8-4F1B-8C84-A3048A45936F].Guid AS EndRibaStageId
,	[1C74EDD6-BB3C-4C47-BCEF-EDE008AABD2F].Guid AS EnquiryId
,	root_hobt.Guid
,	root_hobt.ID
,	[75B5C70B-C121-4A6F-A632-2502321E9933].Guid AS JobTypeId
,	root_hobt.RowStatus
,	root_hobt.RowVersion
,	[036A7B03-4083-4695-A6AE-64D5F5C2C430].Guid AS StartRibaStageId

FROM SSop.EnquiryServices AS root_hobt 
JOIN SJob.RibaStages AS [8AA3EE8C-0AA8-4F1B-8C84-A3048A45936F] ON ([8AA3EE8C-0AA8-4F1B-8C84-A3048A45936F].ID = root_hobt.EndRibaStageId) 
 JOIN SSop.Enquiries AS [1C74EDD6-BB3C-4C47-BCEF-EDE008AABD2F] ON ([1C74EDD6-BB3C-4C47-BCEF-EDE008AABD2F].ID = root_hobt.EnquiryId) 
 JOIN SJob.JobTypes AS [75B5C70B-C121-4A6F-A632-2502321E9933] ON ([75B5C70B-C121-4A6F-A632-2502321E9933].ID = root_hobt.JobTypeId) 
 JOIN SJob.RibaStages AS [036A7B03-4083-4695-A6AE-64D5F5C2C430] ON ([036A7B03-4083-4695-A6AE-64D5F5C2C430].ID = root_hobt.StartRibaStageId) 
' WHERE ID = 170
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.AgentAddress,
	root_hobt.AgentAddressBlock,
	root_hobt.AgentAddressLine1,
	root_hobt.AgentAddressLine2,
	root_hobt.AgentAddressLine3,
	root_hobt.AgentCompanyRegNo,
	root_hobt.AgentContactName,
	root_hobt.AgentCounty,
	root_hobt.AgentEmail,
	root_hobt.AgentFirstName,
	root_hobt.AgentMobile,
	root_hobt.AgentName,
	root_hobt.AgentPhone,
	root_hobt.AgentPostcode,
	root_hobt.AgentSurname,
	root_hobt.AgentTown,
	root_hobt.AgreedFee,
	root_hobt.AppointedJobType,
	root_hobt.ClientAddress,
	root_hobt.ClientAddressBlock,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientCompanyRegNo,
	root_hobt.ClientContactName,
	root_hobt.ClientCounty,
	root_hobt.ClientEmail,
	root_hobt.ClientFirstName,
	root_hobt.ClientMobile,
	root_hobt.ClientName,
	root_hobt.ClientPhone,
	root_hobt.ClientPostcode,
	root_hobt.ClientSurname,
	root_hobt.ClientTown,
	root_hobt.ConstructionStageFee,
	root_hobt.CPPReviewed,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.JobDescription,
	root_hobt.JobIDString,
	root_hobt.JobNumber,
	root_hobt.JobType,
	root_hobt.LocalAuthority,
	root_hobt.OfficialAddressLine1,
	root_hobt.OfficialAddressLine2,
	root_hobt.OfficialAddressLine3,
	root_hobt.OfficialCounty,
	root_hobt.OfficialEmail,
	root_hobt.OfficialMobile,
	root_hobt.OfficialName,
	root_hobt.OfficialPhone,
	root_hobt.OfficialPostcode,
	root_hobt.OfficialTown,
	root_hobt.ParentGuid,
	root_hobt.PCII,
	root_hobt.PreConstructionStageFee,
	root_hobt.PrincipalContractorAddress,
	root_hobt.PrincipalContractorEmail,
	root_hobt.PrincipalContractorMobile,
	root_hobt.PrincipalContractorName,
	root_hobt.PrincipalContractorPhone,
	root_hobt.PropertyAddress,
	root_hobt.PropertyAddressBlock,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	root_hobt.PropertyCounty,
	root_hobt.PropertyPostcode,
	root_hobt.PropertyShortAddress,
	root_hobt.PropertyTown,
	root_hobt.RibaStage1Fee,
	root_hobt.RibaStage2Fee,
	root_hobt.RibaStage3Fee,
	root_hobt.RibaStage4Fee,
	root_hobt.RibaStage5Fee,
	root_hobt.RibaStage6Fee,
	root_hobt.RibaStage7Fee,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SiteCompletionDate,
	root_hobt.SiteStartDate,
	root_hobt.StrategyLastUpdated,
	root_hobt.SurveyorEmail,
	root_hobt.SurveyorInitials,
	root_hobt.SurveyorJobTitle,
	root_hobt.SurveyorName,
	root_hobt.SurveyorPostNominals,
	root_hobt.TotalNetFee,
	root_hobt.UPRN,
	root_hobt.WrittenAppointmentDate
FROM SJob.Job_CDMMergeInfo AS root_hobt 
' WHERE ID = 190
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.ClientAddress,
	root_hobt.ClientAddressBlock,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientCompanyRegNo,
	root_hobt.ClientContactName,
	root_hobt.ClientCounty,
	root_hobt.ClientEmail,
	root_hobt.ClientFirstName,
	root_hobt.ClientMobile,
	root_hobt.ClientName,
	root_hobt.ClientPhone,
	root_hobt.ClientPostcode,
	root_hobt.ClientSurname,
	root_hobt.ClientTown,
	root_hobt.Construction,
	root_hobt.FeeCap,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.OfficialAddressLine1,
	root_hobt.OfficialAddressLine2,
	root_hobt.OfficialAddressLine3,
	root_hobt.OfficialCounty,
	root_hobt.OfficialEmail,
	root_hobt.OfficialMobile,
	root_hobt.OfficialName,
	root_hobt.OfficialPhone,
	root_hobt.OfficialPostcode,
	root_hobt.OfficialTown,
	root_hobt.PreConstruction,
	root_hobt.PropertyAddress,
	root_hobt.PropertyAddressBlock,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	root_hobt.PropertyCounty,
	root_hobt.PropertyPostcode,
	root_hobt.PropertyShortAddress,
	root_hobt.PropertyTown,
	root_hobt.QuoteDate,
	root_hobt.QuoteNumber,
	root_hobt.QuoteOverview,
	root_hobt.QuotingConsultantEmail,
	root_hobt.QuotingConsultantInitials,
	root_hobt.QuotingConsultantJobTitle,
	root_hobt.QuotingConsultantName,
	root_hobt.QuotingConsultantPostNominals,
	root_hobt.QuotingUserEmail,
	root_hobt.QuotingUserInitials,
	root_hobt.QuotingUserJobTitle,
	root_hobt.QuotingUserName,
	root_hobt.QuotingUserPostNominals,
	root_hobt.RecipientAddress,
	root_hobt.RecipientAddressBlock,
	root_hobt.RecipientAddressLine1,
	root_hobt.RecipientAddressLine2,
	root_hobt.RecipientAddressLine3,
	root_hobt.RecipientCompanyRegNo,
	root_hobt.RecipientContactName,
	root_hobt.RecipientCounty,
	root_hobt.RecipientEmail,
	root_hobt.RecipientFirstName,
	root_hobt.RecipientMobile,
	root_hobt.RecipientName,
	root_hobt.RecipientPhone,
	root_hobt.RecipientPostcode,
	root_hobt.RecipientSurname,
	root_hobt.RecipientTown,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.Stage1Net,
	root_hobt.Stage2Net,
	root_hobt.Stage3Net,
	root_hobt.Stage4Net,
	root_hobt.Stage5Net,
	root_hobt.Stage6Net,
	root_hobt.Stage7Net,
	root_hobt.TotalNetFees,
	root_hobt.UPRN
FROM SSop.Quote_MergeInfo AS root_hobt 
' WHERE ID = 191
UPDATE SCore.EntityQueries SET Statement = N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		j.Guid AS JobID,
		i.Guid AS CreatedByUserID,
		root_hobt.CreatedDateTime,
		root_hobt.RibaStage0Change,
		root_hobt.RibaStage1Change,
		root_hobt.RibaStage2Change,
		root_hobt.RibaStage3Change,
		root_hobt.RibaStage4Change,
		root_hobt.RibaStage5Change,
		root_hobt.RibaStage6Change,
		root_hobt.RibaStage7Change,

		-- VISIT CHANGES
        root_hobt.RibaStage0VisitChange,
        root_hobt.RibaStage1VisitChange,
		root_hobt.RibaStage2VisitChange,
		root_hobt.RibaStage3VisitChange,
		root_hobt.RibaStage4VisitChange,
		root_hobt.RibaStage5VisitChange,
		root_hobt.RibaStage6VisitChange,
		root_hobt.RibaStage7VisitChange,

		--MEETING CHANGES
        root_hobt.RibaStage0MeetingChange,
        root_hobt.RibaStage1MeetingChange,
		root_hobt.RibaStage2MeetingChange,
		root_hobt.RibaStage3MeetingChange,
		root_hobt.RibaStage4MeetingChange,
		root_hobt.RibaStage5MeetingChange,
		root_hobt.RibaStage6MeetingChange,
		root_hobt.RibaStage7MeetingChange,

		
		root_hobt.PreConstructionStageChange,
		root_hobt.ConstructionStageChange,
		-- PRE + CONSTRUCTION CHANGES
		root_hobt.PreConstructionStageMeetingChange,
		root_hobt.PreConstructionStageVisitChange,
		root_hobt.ConstructionStageMeetingChange,
		root_hobt.ConstructionStageVisitChange,

		root_hobt.FeeCapChange
FROM	SJob.FeeAmendment root_hobt
JOIN	SJob.Jobs j ON (j.ID = root_hobt.JobID)
JOIN	SCore.Identities i ON (i.ID = root_hobt.CreatedByUserID)' WHERE ID = 192
UPDATE SCore.EntityQueries SET Statement = N'EXEC SJob.FeeAmendmentsUpsert @JobGuid = @JobGuid,			-- uniqueidentifier
							  @RibaStage0Change = @RibaStage0Change, -- decimal(9, 2)
							  @RibaStage1Change = @RibaStage1Change, -- decimal(9, 2)
							  @RibaStage2Change = @RibaStage2Change, -- decimal(9, 2)
							  @RibaStage3Change = @RibaStage3Change, -- decimal(9, 2)
							  @RibaStage4Change = @RibaStage4Change, -- decimal(9, 2)
							  @RibaStage5Change = @RibaStage5Change, -- decimal(9, 2)
							  @RibaStage6Change = @RibaStage6Change, -- decimal(9, 2)
							  @RibaStage7Change = @RibaStage7Change, -- decimal(9, 2)
                                                          
                                                           -- Visits
                                                          @RibaStage0VisitChange = @RibaStage0VisitChange, -- decimal(9, 2)
							  @RibaStage1VisitChange = @RibaStage1VisitChange, -- decimal(9, 2)
							  @RibaStage2VisitChange = @RibaStage2VisitChange, -- decimal(9, 2)
							  @RibaStage3VisitChange = @RibaStage3VisitChange, -- decimal(9, 2)
							  @RibaStage4VisitChange = @RibaStage4VisitChange, -- decimal(9, 2)
							  @RibaStage5VisitChange = @RibaStage5VisitChange, -- decimal(9, 2)
							  @RibaStage6VisitChange = @RibaStage6VisitChange, -- decimal(9, 2)
							  @RibaStage7VisitChange = @RibaStage7VisitChange, -- decimal(9, 2)

                                                           -- Meetings
                                                          @RibaStage0MeetingChange = @RibaStage0MeetingChange, -- decimal(9, 2)
							  @RibaStage1MeetingChange = @RibaStage1MeetingChange, -- decimal(9, 2)
							  @RibaStage2MeetingChange = @RibaStage2MeetingChange, -- decimal(9, 2)
							  @RibaStage3MeetingChange = @RibaStage3MeetingChange, -- decimal(9, 2)
							  @RibaStage4MeetingChange = @RibaStage4MeetingChange, -- decimal(9, 2)
							  @RibaStage5MeetingChange = @RibaStage5MeetingChange, -- decimal(9, 2)
							  @RibaStage6MeetingChange = @RibaStage6MeetingChange, -- decimal(9, 2)
							  @RibaStage7MeetingChange = @RibaStage7MeetingChange, -- decimal(9, 2)

							  @PreConstructionStageChange = @PreConstructionStageChange,
							  @ConstructionStageChange = @ConstructionStageChange,

                                                           -- construction + preconstruction
                                                            @PreConstructionStageMeetingChange = @PreConstructionStageMeetingChange,
			                                    @PreConstructionStageVisitChange = @PreConstructionStageVisitChange,
			                                   @ConstructionStageMeetingChange = @ConstructionStageMeetingChange,
			                                   @ConstructionStageVisitChange =  @ConstructionStageVisitChange,
							  @FeeCapChange = @FeeCapChange,		-- decimal(9, 2)
							  @Guid = @Guid				-- uniqueidentifier
' WHERE ID = 193
UPDATE SCore.EntityQueries SET Statement = N'SELECT ID AS Account_ID,
	   Guid,
	   RowStatus,
	   RowVersion,
	   MainAddress,
	   MainPhone,
	   MainEmail
FROM	SCrm.Accounts_CalculatedFields root_hobt' WHERE ID = 209
UPDATE SCore.EntityQueries SET Statement = N'
SELECT 
	[3D00EDE9-26D4-47DA-95BE-7374C084BADD].Guid AS AgentAccountId,
	[D8D47C34-0EA4-41F0-950D-DB45011865AA].Guid AS ClientAccountId,
	root_hobt.DescriptionOfWorks,
	[9B2655E2-4696-4B1E-9013-DA6AFE6CB728].Guid AS EnquiryId,
	root_hobt.JobType,
        root_hobt.JobTypeGuid,
	[0E518042-9A71-44B7-8549-305DB3E09225].Guid AS PropertyId,
	root_hobt.QuotingDeadlineDate
FROM SSop.Quote_ExtendedInfo AS root_hobt 
JOIN SCrm.Accounts AS [D8D47C34-0EA4-41F0-950D-DB45011865AA] ON ([D8D47C34-0EA4-41F0-950D-DB45011865AA].ID = root_hobt.ClientAccountId) 
 JOIN SCrm.Accounts AS [3D00EDE9-26D4-47DA-95BE-7374C084BADD] ON ([3D00EDE9-26D4-47DA-95BE-7374C084BADD].ID = root_hobt.AgentAccountId) 
 JOIN SJob.Properties AS [0E518042-9A71-44B7-8549-305DB3E09225] ON ([0E518042-9A71-44B7-8549-305DB3E09225].ID = root_hobt.PropertyId) 
 JOIN SSop.Enquiries AS [9B2655E2-4696-4B1E-9013-DA6AFE6CB728] ON ([9B2655E2-4696-4B1E-9013-DA6AFE6CB728].ID = root_hobt.EnquiryId) 
' WHERE ID = 212
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.AcceptedQuotesCount,
	root_hobt.AcceptedQuotesTotalValue,
	root_hobt.EnquiriesCount,
	root_hobt.Guid,
	root_hobt.Id,
	root_hobt.JobsActiveAgreedFeesTotal,
	root_hobt.JobsActiveCount,
	root_hobt.JobsActiveInvoicedFeesTotal,
	root_hobt.JobsActiveRemainingFeesTotal,
	root_hobt.JobsCancelledAgreedFeesTotal,
	root_hobt.JobsCancelledCount,
	root_hobt.JobsCancelledInvoicedFeesTotal,
	root_hobt.JobsCancelledUninvoicedFeesTotal,
	root_hobt.JobsCompletedAgreedFeesTotal,
	root_hobt.JobsCompletedCount,
	root_hobt.JobsCompletedInvoicedFeesTotal,
	root_hobt.JobsCompletedUninvoicesFeesTotal,
	root_hobt.JobsCount,
	root_hobt.JobsTotalAgreedFeesTotal,
	root_hobt.JobsTotalInvoicedFeesTotal,
	root_hobt.JobsTotalRemainingFeesTotal,
	root_hobt.ListLabel,
	root_hobt.PendingQuotesCount,
	root_hobt.PendingQuotesTotelValue,
	root_hobt.PercentageAchievableRevenueAchieved,
	root_hobt.PercentageCompleted,
	root_hobt.QuotesCount,
	root_hobt.QuotesTotalValue,
	root_hobt.RejectedQuotesCount,
	root_hobt.RejectedQuotesTotalValue,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.Project_ExtendedInfo AS root_hobt 
' WHERE ID = 213
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.ExternalReference
,	root_hobt.Guid
,	root_hobt.ID
,	root_hobt.Number
,	root_hobt.ProjectCompleted
,	root_hobt.ProjectDescription
,	root_hobt.ProjectProjectedEndDate
,	root_hobt.ProjectProjectsStartDate
,	root_hobt.RowStatus
,	root_hobt.RowVersion
,	root_hobt.IsSubjectToNDA

FROM SSop.Projects AS root_hobt 
' WHERE ID = 214
UPDATE SCore.EntityQueries SET Statement = N'SELECT	root_hobt.ID,
		root_hobt.Label,
		root_hobt.Class,
		root_hobt.SortOrder 
FROM	[SJob].[Activities_DataPills](@SurveyorGuid, @BillableHours, @JobGuid, @RibaStageGuid, @IsAdditionalWork, @Guid) root_hobt' WHERE ID = 257
UPDATE SCore.EntityQueries SET Statement = N'SELECT
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Notes,
		i.Guid as RequesterUserId,
		root_hobt.CreatedDateTimeUTC,
		j.Guid as JobId,
        j.Number as Number,
        i.FullName as SurveyorName,
        Ac.Guid as FinanceAccountID, -- new
        j.BillingInstruction AS JobBillingInstruction, -- [CBLD-521]
	Ac.BillingInstruction AS AccountBillingInstruction -- [CBLD-521]
FROM
		SFin.InvoiceRequests root_hobt
JOIN
		SJob.Jobs j ON (j.ID = root_hobt.JobId)
JOIN
		SCrm.Accounts Ac ON (j.FinanceAccountID = Ac.ID) -- new
JOIN
		SCore.Identities i ON (i.ID = root_hobt.RequesterUserId)' WHERE ID = 258
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.Guid,
	root_hobt.ID,
	[E779FDBF-3727-4C37-B19D-4BCC6F71314F].Guid AS IncludedMergeDocumentId,
	[0BEC90D5-4330-467B-B271-2D2A4364D00F].Guid AS MergeDocumentItemId,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SortOrder,
	[A7575B42-582C-4E04-A3C4-59ADA04EF33A].Guid AS SourceDocumentEntityPropertyId,
	[1A289995-4638-4F67-B706-CD3E3E3C80E0].Guid AS SourceSharePointItemEntityPropertyId
FROM SCore.MergeDocumentItemIncludes AS root_hobt 
JOIN SCore.MergeDocumentItems AS [0BEC90D5-4330-467B-B271-2D2A4364D00F] ON ([0BEC90D5-4330-467B-B271-2D2A4364D00F].ID = root_hobt.MergeDocumentItemId) 
 JOIN SCore.EntityProperties AS [A7575B42-582C-4E04-A3C4-59ADA04EF33A] ON ([A7575B42-582C-4E04-A3C4-59ADA04EF33A].ID = root_hobt.SourceDocumentEntityPropertyId) 
 JOIN SCore.EntityProperties AS [1A289995-4638-4F67-B706-CD3E3E3C80E0] ON ([1A289995-4638-4F67-B706-CD3E3E3C80E0].ID = root_hobt.SourceSharePointItemEntityPropertyId) 
 JOIN SCore.MergeDocuments AS [E779FDBF-3727-4C37-B19D-4BCC6F71314F] ON ([E779FDBF-3727-4C37-B19D-4BCC6F71314F].ID = root_hobt.IncludedMergeDocumentId) 
' WHERE ID = 272
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.BookmarkName,
	[02A636D3-60AA-4516-8303-3B12D2497685].Guid AS EntityTypeId,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.ImageColumns,
	[B86CAFA7-C6E8-4AC5-A606-7A2289ACDDC9].Guid AS MergeDocumentId,
	[9BFBE9EC-9DDB-4FCC-8513-9EB5F2C1593C].Guid AS MergeDocumentItemTypeId,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SubFolderPath
FROM SCore.MergeDocumentItems AS root_hobt 
JOIN SCore.MergeDocuments AS [B86CAFA7-C6E8-4AC5-A606-7A2289ACDDC9] ON ([B86CAFA7-C6E8-4AC5-A606-7A2289ACDDC9].ID = root_hobt.MergeDocumentId) 
 JOIN SCore.MergeDocumentItemTypes AS [9BFBE9EC-9DDB-4FCC-8513-9EB5F2C1593C] ON ([9BFBE9EC-9DDB-4FCC-8513-9EB5F2C1593C].ID = root_hobt.MergeDocumentItemTypeId) 
 JOIN SCore.EntityTypes AS [02A636D3-60AA-4516-8303-3B12D2497685] ON ([02A636D3-60AA-4516-8303-3B12D2497685].ID = root_hobt.EntityTypeId) 
' WHERE ID = 273
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.ID
,	root_hobt.Guid
,	root_hobt.RowStatus
,	root_hobt.RowVersion
,	root_hobt.Name
,	root_hobt.IsImageType

FROM SCore.MergeDocumentItemTypes AS root_hobt 
' WHERE ID = 276
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.ID
,	root_hobt.Guid
,	root_hobt.RowStatus
,	root_hobt.RowVersion
,	[E9D4ABB8-AACF-4ECF-8EAC-1DFA642106F7].Guid AS ProjectID
,	root_hobt.Detail
,	root_hobt.DateTime

FROM SSop.ProjectKeyDates AS root_hobt 
JOIN SSop.Projects AS [E9D4ABB8-AACF-4ECF-8EAC-1DFA642106F7] ON ([E9D4ABB8-AACF-4ECF-8EAC-1DFA642106F7].ID = root_hobt.ProjectID) 
' WHERE ID = 281
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	[CF303924-00E4-4D84-8E04-16B74316BD33].Guid AS QuoteId
,	root_hobt.DateAccepted
,	root_hobt.DateSent
,	root_hobt.DateRejected
,	root_hobt.Number
,	root_hobt.RevisionNumber
,       root_hobt.DeclinedToQuoteDate
,       root_hobt.DeclinedToQuoteReason
FROM SSop.EnquiryService_ExtendedInfo AS root_hobt 
JOIN SSop.Quotes AS [CF303924-00E4-4D84-8E04-16B74316BD33] ON ([CF303924-00E4-4D84-8E04-16B74316BD33].ID = root_hobt.QuoteId) 
' WHERE ID = 287
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SSop].[EnquiryServicesExtUpsert]  
	@DateSent = @DateSent, 
	@DateAccepted = @DateAccepted, 
	@DateRejected = @DateRejected, 
	@DateDeclinedToQuote = @DateDeclinedToQuote, 
	@DateDeclinedToQuoteReason = @DateDeclinedToQuoteReason, 
	@QuoteGuid = @QuoteGuid, 
	@Guid = @Guid' WHERE ID = 288
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SSop].[EnquiryCreateJobs]  
	@Guid = @Guid' WHERE ID = 289
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SSop].[QuoteDelete]  
	@Guid = @Guid' WHERE ID = 290
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.AgentAddress,
	root_hobt.AgentAddressBlock,
	root_hobt.AgentAddressLine1,
	root_hobt.AgentAddressLine2,
	root_hobt.AgentAddressLine3,
	root_hobt.AgentCompanyRegNo,
	root_hobt.AgentContactName,
	root_hobt.AgentCounty,
	root_hobt.AgentEmail,
	root_hobt.AgentFirstName,
	root_hobt.AgentMobile,
	root_hobt.AgentName,
	root_hobt.AgentPhone,
	root_hobt.AgentPostcode,
	root_hobt.AgentSurname,
	root_hobt.AgentTown,
	root_hobt.ClientAddress,
	root_hobt.ClientAddressBlock,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientCompanyRegNo,
	root_hobt.ClientContactName,
	root_hobt.ClientCounty,
	root_hobt.ClientEmail,
	root_hobt.ClientFirstName,
	root_hobt.ClientMobile,
	root_hobt.ClientName,
	root_hobt.ClientPhone,
	root_hobt.ClientPostcode,
	root_hobt.ClientSurname,
	root_hobt.ClientTown,
	root_hobt.DescriptionOfWorks,
	root_hobt.EnquiryDate,
	root_hobt.EnquiryNumber,
	root_hobt.FinanceAddress,
	root_hobt.FinanceAddressBlock,
	root_hobt.FinanceAddressLine1,
	root_hobt.FinanceAddressLine2,
	root_hobt.FinanceAddressLine3,
	root_hobt.FinanceCompanyRegNo,
	root_hobt.FinanceContactName,
	root_hobt.FinanceCounty,
	root_hobt.FinanceEmail,
	root_hobt.FinanceFirstName,
	root_hobt.FinanceMobile,
	root_hobt.FinanceName,
	root_hobt.FinancePhone,
	root_hobt.FinancePostcode,
	root_hobt.FinanceSurname,
	root_hobt.FinanceTown,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.OfficialAddressLine1,
	root_hobt.OfficialAddressLine2,
	root_hobt.OfficialAddressLine3,
	root_hobt.OfficialCounty,
	root_hobt.OfficialEmail,
	root_hobt.OfficialMobile,
	root_hobt.OfficialName,
	root_hobt.OfficialPhone,
	root_hobt.OfficialPostcode,
	root_hobt.OfficialTown,
	root_hobt.ParentGuid,
	root_hobt.PropertyAddress,
	root_hobt.PropertyAddressBlock,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	root_hobt.PropertyCounty,
	root_hobt.PropertyPostcode,
	root_hobt.PropertyShortAddress,
	root_hobt.PropertyTown,
	root_hobt.ProposalLetter,
	root_hobt.RecipientAddress,
	root_hobt.RecipientAddressBlock,
	root_hobt.RecipientAddressLine1,
	root_hobt.RecipientAddressLine2,
	root_hobt.RecipientAddressLine3,
	root_hobt.RecipientCompanyRegNo,
	root_hobt.RecipientContactName,
	root_hobt.RecipientCounty,
	root_hobt.RecipientEmail,
	root_hobt.RecipientFirstName,
	root_hobt.RecipientMobile,
	root_hobt.RecipientName,
	root_hobt.RecipientPhone,
	root_hobt.RecipientPostcode,
	root_hobt.RecipientSurname,
	root_hobt.RecipientTown,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SignatoryInitials,
	root_hobt.SignatoryJobTitle,
	root_hobt.SignatoryName,
	root_hobt.SignatoryPostNominals,
	root_hobt.SignatorytEmail,
	root_hobt.TotalFee,
	root_hobt.UPRN
FROM SSop.Enquiry_MergeInfo AS root_hobt 
' WHERE ID = 291
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	[56C69394-5430-42BA-A4E2-4D12A3D0777C].Guid AS EnquiryId,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.Item,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.ScheduleOfClientInformation AS root_hobt 
JOIN SSop.Enquiries AS [56C69394-5430-42BA-A4E2-4D12A3D0777C] ON ([56C69394-5430-42BA-A4E2-4D12A3D0777C].ID = root_hobt.EnquiryId) 
' WHERE ID = 292
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SSop].[ScheduleOfClientInformationUpsert]  
	@EnquiryGuid = @EnquiryGuid, 
	@Item = @Item, 
	@Guid = @Guid' WHERE ID = 293
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.EnquiryGuid,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.ParentGuid,
	root_hobt.QuoteGuid,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.EnquiryService_MergeInfo AS root_hobt 
' WHERE ID = 295
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.Item,
	root_hobt.ParentGuid,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.ScheduleOfClientInfo_MergeInfo AS root_hobt 
' WHERE ID = 296
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.Accept,
	root_hobt.EnquiryGuid,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.Name,
	root_hobt.ParentGuid,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.EnquiryAcceptanceServices_MergeInfo AS root_hobt 
' WHERE ID = 297
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SCore].[MergeDocumentsDelete]  
	@Guid = @Guid' WHERE ID = 298
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SUserInterface].[GridViewDefinitionsDelete]  
	@Guid = @Guid' WHERE ID = 299
UPDATE SCore.EntityQueries SET Statement = N'EXEC [SUserInterface].[GridViewColumnDefinitionsDelete]  
	@Guid = @Guid' WHERE ID = 300
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.Description,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.LineNet,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.QuoteItems_MergeInfo AS root_hobt 
' WHERE ID = 301
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.ActivityDate,
	root_hobt.ActivityNotes,
	root_hobt.ActivityTitle,
	root_hobt.ActivityType,
	root_hobt.AgentAddress,
	root_hobt.AgentAddressBlock,
	root_hobt.AgentAddressLine1,
	root_hobt.AgentAddressLine2,
	root_hobt.AgentAddressLine3,
	root_hobt.AgentCompanyRegNo,
	root_hobt.AgentContactName,
	root_hobt.AgentCounty,
	root_hobt.AgentEmail,
	root_hobt.AgentFirstName,
	root_hobt.AgentMobile,
	root_hobt.AgentName,
	root_hobt.AgentPhone,
	root_hobt.AgentPostcode,
	root_hobt.AgentSurname,
	root_hobt.AgentTown,
	root_hobt.ClientAddress,
	root_hobt.ClientAddressBlock,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientCompanyRegNo,
	root_hobt.ClientContactName,
	root_hobt.ClientCounty,
	root_hobt.ClientEmail,
	root_hobt.ClientFirstName,
	root_hobt.ClientMobile,
	root_hobt.ClientName,
	root_hobt.ClientPhone,
	root_hobt.ClientPostcode,
	root_hobt.ClientSurname,
	root_hobt.ClientTown,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.JobDescription,
	root_hobt.JobNumber,
	root_hobt.JobType,
	root_hobt.LocalAuthority,
	root_hobt.OfficialAddressLine1,
	root_hobt.OfficialAddressLine2,
	root_hobt.OfficialAddressLine3,
	root_hobt.OfficialCounty,
	root_hobt.OfficialEmail,
	root_hobt.OfficialMobile,
	root_hobt.OfficialName,
	root_hobt.OfficialPhone,
	root_hobt.OfficialPostcode,
	root_hobt.OfficialTown,
	root_hobt.ParentGuid,
	root_hobt.PropertyAddress,
	root_hobt.PropertyAddressBlock,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	root_hobt.PropertyCounty,
	root_hobt.PropertyPostcode,
	root_hobt.PropertyShortAddress,
	root_hobt.PropertyTown,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SurveyorEmail,
	root_hobt.SurveyorInitials,
	root_hobt.SurveyorJobTitle,
	root_hobt.SurveyorName,
	root_hobt.SurveyorPostNominals,
	root_hobt.UPRN
FROM SJob.Activity_MergeInfo AS root_hobt 
' WHERE ID = 303
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.DisplayName,
	root_hobt.Email,
	root_hobt.FirstName,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.Mobile,
	root_hobt.ParentGuid,
	root_hobt.Phone,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.Surname
FROM SCrm.Contact_MergeInfo AS root_hobt 
' WHERE ID = 304
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.AgentAddress,
	root_hobt.AgentAddressBlock,
	root_hobt.AgentAddressLine1,
	root_hobt.AgentAddressLine2,
	root_hobt.AgentAddressLine3,
	root_hobt.AgentCompanyRegNo,
	root_hobt.AgentContactName,
	root_hobt.AgentCounty,
	root_hobt.AgentEmail,
	root_hobt.AgentFirstName,
	root_hobt.AgentMobile,
	root_hobt.AgentName,
	root_hobt.AgentPhone,
	root_hobt.AgentPostcode,
	root_hobt.AgentSurname,
	root_hobt.AgentTown,
	root_hobt.AgreedFee,
	root_hobt.ClientAddress,
	root_hobt.ClientAddressBlock,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientAppointmentReceived,
	root_hobt.ClientCompanyRegNo,
	root_hobt.ClientContactName,
	root_hobt.ClientCounty,
	root_hobt.ClientEmail,
	root_hobt.ClientFirstName,
	root_hobt.ClientMobile,
	root_hobt.ClientName,
	root_hobt.ClientPhone,
	root_hobt.ClientPostcode,
	root_hobt.ClientSurname,
	root_hobt.ClientTown,
	root_hobt.ConstructionStageFee,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.JobDescription,
	root_hobt.JobIDString,
	root_hobt.JobNumber,
	root_hobt.JobType,
	root_hobt.LocalAuthority,
	root_hobt.OfficialAddressLine1,
	root_hobt.OfficialAddressLine2,
	root_hobt.OfficialAddressLine3,
	root_hobt.OfficialCounty,
	root_hobt.OfficialEmail,
	root_hobt.OfficialMobile,
	root_hobt.OfficialName,
	root_hobt.OfficialPhone,
	root_hobt.OfficialPostcode,
	root_hobt.OfficialTown,
	root_hobt.PreConstructionStageFee,
	root_hobt.PropertyAddress,
	root_hobt.PropertyAddressBlock,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	root_hobt.PropertyCounty,
	root_hobt.PropertyPostcode,
	root_hobt.PropertyShortAddress,
	root_hobt.PropertyTown,
	root_hobt.RibaStage1Fee,
	root_hobt.RibaStage2Fee,
	root_hobt.RibaStage3Fee,
	root_hobt.RibaStage4Fee,
	root_hobt.RibaStage5Fee,
	root_hobt.RibaStage6Fee,
	root_hobt.RibaStage7Fee,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SurveyorEmail,
	root_hobt.SurveyorInitials,
	root_hobt.SurveyorJobTitle,
	root_hobt.SurveyorName,
	root_hobt.SurveyorPostNominals,
	root_hobt.TotalNetFee,
	root_hobt.UPRN
FROM SJob.Job_MergeInfo AS root_hobt 
' WHERE ID = 305
UPDATE SCore.EntityQueries SET Statement = N'SELECT 
	root_hobt.ActivityEndDate,
	root_hobt.ActivityNotes,
	root_hobt.ActivityStartDate,
	root_hobt.ActivityTitle,
	root_hobt.ActivityType,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.ParentGuid,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SurveyorName
FROM SJob.Activity_Table_MergeInfo AS root_hobt 
' WHERE ID = 306
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Inserting data into table [SCore].[LanguageLabels]
--
SET IDENTITY_INSERT SCore.LanguageLabels ON
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
INSERT SCore.LanguageLabels(ID, RowStatus, Guid, Name) VALUES (2822, 1, '51fd4a8b-4986-4994-b232-05f2818d5b1e', N'[SCrm].[tvf_AccountsWithSageCode].[Grid]')
INSERT SCore.LanguageLabels(ID, RowStatus, Guid, Name) VALUES (2823, 1, 'a6c180d1-134f-480e-9910-77c1a77345fb', N'[SCrm].[tvf_AccountsWithSageCode].[Code]')
GO
SET IDENTITY_INSERT SCore.LanguageLabels OFF
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Reseed identity on SCore.LanguageLabels
--
DBCC CHECKIDENT('SCore.LanguageLabels', RESEED, 2823)
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Updating data of table [SCore].[LanguageLabelTranslations]
--
UPDATE SCore.LanguageLabelTranslations SET Text = N'Accounts (All)', TextPlural = N'Accounts (All)' WHERE ID = 1892

--
-- Inserting data into table [SCore].[LanguageLabelTranslations]
--
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
SET IDENTITY_INSERT SCore.LanguageLabelTranslations ON
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
INSERT SCore.LanguageLabelTranslations(ID, RowStatus, Guid, Text, TextPlural, LanguageLabelID, LanguageID, HelpText) VALUES (2862, 1, '1ee0bb9b-c04b-4fe9-9bc2-32a6bb634b73', N'Accounts (Finance)', N'Accounts (Finance)', 2822, 1, N'')
INSERT SCore.LanguageLabelTranslations(ID, RowStatus, Guid, Text, TextPlural, LanguageLabelID, LanguageID, HelpText) VALUES (2863, 1, '92a046d2-8313-4a8a-96ba-ead337189640', N'Code  (Sage)', N'Code  (Sage)', 2823, 1, N'')
GO
SET IDENTITY_INSERT SCore.LanguageLabelTranslations OFF
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Reseed identity on SCore.LanguageLabelTranslations
--
DBCC CHECKIDENT('SCore.LanguageLabelTranslations', RESEED, 2863)
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Updating data of table [SUserInterface].[DropDownListDefinitions]
--
UPDATE SUserInterface.DropDownListDefinitions SET SqlQuery = N'SELECT	TOP(10) root_hobt.Guid,
		root_hobt.Name
FROM	SSop.Contracts_DDL root_hobt
WHERE	(root_hobt.AccountGuid = ''[[ParentGuid]]'')' WHERE ID = 30
UPDATE SUserInterface.DropDownListDefinitions SET SqlQuery = N'SELECT  root_hobt.Guid, 
		(CASE WHEN root_hobt.Title = '''' THEN ''-'' ELSE CONCAT(root_hobt.Title, '' '', CASE WHEN Act.IsBillable = 1 THEN ''(Billable)'' ELSE ''(Non-Billable)'' END) END) AS Title,
                Act.IsBillable
FROM    SJob.Activities root_hobt
JOIN    SJob.ActivityTypes AS Act ON (root_hobt.ActivityTypeID = Act.ID)
WHERE	(EXISTS 
			(
				SELECT	1
				FROM	SFin.InvoiceRequests AS ir
				WHERE	(ir.Guid = ''[[ParentGuid]]'')
					AND	(ir.JobId = root_hobt.JobID)
			)
		)  


' WHERE ID = 84
UPDATE SUserInterface.DropDownListDefinitions SET SqlQuery = N'SELECT 
		ac.Name,
		ac.Guid
FROM 
		SJob.Jobs root_hobt
INNER JOIN SCrm.Accounts ac ON (ac.ID = root_hobt.FinanceAccountID)
WHERE (root_hobt.Guid =  ''[[ParentGuid]]'')' WHERE ID = 86
UPDATE SUserInterface.DropDownListDefinitions SET SqlQuery = N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SCore.MergeDocumentItemTypes AS root_hobt' WHERE ID = 87
UPDATE SUserInterface.DropDownListDefinitions SET SqlQuery = N'SELECT	root_hobt.Guid,
		root_hobt.BookmarkName
FROM	SCore.MergeDocumentItems AS root_hobt' WHERE ID = 88
UPDATE SUserInterface.DropDownListDefinitions SET SqlQuery = N'SELECT	root_hobt.Guid, 
		root_hobt.Name
FROM	SSop.EnquiryService_DDL root_hobt' WHERE ID = 89
UPDATE SUserInterface.DropDownListDefinitions SET SqlQuery = N'SELECT	TOP(10) root_hobt.ListName, 
		root_hobt.Guid
FROM	SProd.tvf_Products(1) root_hobt
WHERE	((root_hobt.CreatedJobType = -1)
	OR	(EXISTS
			(
				SELECT	1
				FROM	SSop.Quotes AS q
				JOIN	SSop.EnquiryServices es ON (es.ID = q.EnquiryServiceID)
				WHERE	(es.JobTypeId = root_hobt.CreatedJobType)
					AND	(q.Guid = ''[[ParentGuid]]'')
			)
		))' WHERE ID = 90
UPDATE SUserInterface.DropDownListDefinitions SET SqlQuery = N'SELECT TOP(10) root_hobt.Guid,
           CASE WHEN root_hobt.Code <> '''' THEN root_hobt.Name + '' - '' + root_hobt.Code
                ELSE root_hobt.Name
           END AS Name
    FROM SCrm.Accounts root_hobt' WHERE ID = 91
UPDATE SUserInterface.DropDownListDefinitions SET SqlQuery = N'SELECT TOP(10)
             root_hobt.ConcatenatedNameCode,
             root_hobt.Guid,
             root_hobt.ColourHex
FROM SCrm.LiveSageColourAccounts root_hobt' WHERE ID = 92
UPDATE SUserInterface.DropDownListDefinitions SET SqlQuery = N'SELECT root_hobt.Name, root_hobt.Guid
FROM SJob.JobTypes root_hobt
' WHERE ID = 93
UPDATE SUserInterface.DropDownListDefinitions SET SqlQuery = N'SELECT	TOP(10)
		root_hobt .DisplayName,
		root_hobt .Guid AS ContactGuid
FROM	SCrm.Contacts root_hobt 
JOIN	SCrm.AccountContacts ac  ON (root_hobt .ID = ac.ContactID)
JOIN	SCrm.Accounts a ON (a.ID = ac.AccountID)
WHERE	(root_hobt.RowStatus NOT IN (0, 254))
	AND	(a.RowStatus NOT IN (0, 254))
	AND	(ac.RowStatus NOT IN (0, 254))
        AND         (a.Guid = ''[[ParentGuid]]'')' WHERE ID = 94
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Updating data of table [SUserInterface].[GridViewColumnDefinitions]
--
UPDATE SUserInterface.GridViewColumnDefinitions SET Width = N'100px' WHERE ID = 812
UPDATE SUserInterface.GridViewColumnDefinitions SET IsFiltered = 0 WHERE ID = 945
UPDATE SUserInterface.GridViewColumnDefinitions SET Guid = '510970bc-6c73-4278-b215-6735f0e776bd', Name = N'ID', ColumnOrder = 999, GridViewDefinitionId = 187, IsPrimaryKey = 1, IsHidden = 1, Width = N'', LanguageLabelId = 1627 WHERE ID = 1023

--
-- Inserting data into table [SUserInterface].[GridViewColumnDefinitions]
--
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
SET IDENTITY_INSERT SUserInterface.GridViewColumnDefinitions ON
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
INSERT SUserInterface.GridViewColumnDefinitions(ID, RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, IsLongitude, IsLatitude, DisplayFormat, Width, LanguageLabelId, TopHeaderCategory, TopHeaderCategoryOrder) VALUES (1024, 1, '2665e3af-3d35-41dd-80d4-127fef3b49d6', N'Guid', 0, 187, 0, 1, 0, 0, 0, 0, N'', N'', 1689, N'', 0)
INSERT SUserInterface.GridViewColumnDefinitions(ID, RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, IsLongitude, IsLatitude, DisplayFormat, Width, LanguageLabelId, TopHeaderCategory, TopHeaderCategoryOrder) VALUES (1025, 1, 'fa97f401-06f5-4dda-9594-37c100558fe9', N'Name', 3, 187, 0, 0, 1, 0, 0, 0, N'', N'', 1717, N'', 0)
INSERT SUserInterface.GridViewColumnDefinitions(ID, RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, IsLongitude, IsLatitude, DisplayFormat, Width, LanguageLabelId, TopHeaderCategory, TopHeaderCategoryOrder) VALUES (1026, 1, '2a70ca72-5cf6-4401-bff0-ca305b84cc39', N'Code', 4, 187, 0, 0, 1, 0, 0, 0, N'', N'', 1641, N'', 0)
INSERT SUserInterface.GridViewColumnDefinitions(ID, RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, IsLongitude, IsLatitude, DisplayFormat, Width, LanguageLabelId, TopHeaderCategory, TopHeaderCategoryOrder) VALUES (1027, 1, '0b764114-07fe-48a3-93a0-8519c4672d1c', N'MainContact', 5, 187, 0, 0, 1, 0, 0, 0, N'', N'', 1711, N'', 0)
INSERT SUserInterface.GridViewColumnDefinitions(ID, RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, IsLongitude, IsLatitude, DisplayFormat, Width, LanguageLabelId, TopHeaderCategory, TopHeaderCategoryOrder) VALUES (1028, 1, '7ae99b85-f1c9-4568-b69e-9cf9c697636d', N'MainAddress', 6, 187, 0, 0, 1, 0, 0, 0, N'', N'', 1710, N'', 0)
INSERT SUserInterface.GridViewColumnDefinitions(ID, RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, IsLongitude, IsLatitude, DisplayFormat, Width, LanguageLabelId, TopHeaderCategory, TopHeaderCategoryOrder) VALUES (1029, 1, '8a3de30b-2b75-4366-987f-cfd8aa585be5', N'RelationshipManagerName', 7, 187, 0, 0, 1, 1, 0, 0, N'', N'', 1754, N'', 0)
INSERT SUserInterface.GridViewColumnDefinitions(ID, RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, IsLongitude, IsLatitude, DisplayFormat, Width, LanguageLabelId, TopHeaderCategory, TopHeaderCategoryOrder) VALUES (1030, 1, 'e10bf680-e40e-457a-9d36-8c0c79529f7c', N'AccountStatusName', 8, 187, 0, 0, 1, 1, 0, 0, N'', N'', 1770, N'', 0)
INSERT SUserInterface.GridViewColumnDefinitions(ID, RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, IsLongitude, IsLatitude, DisplayFormat, Width, LanguageLabelId, TopHeaderCategory, TopHeaderCategoryOrder) VALUES (1031, 254, '012877e7-9e08-4e5e-8f0e-07a9cb252e36', N'Account', 0, 34, 0, 0, 0, 0, 0, 0, N'', N'', 2742, N'', 0)
INSERT SUserInterface.GridViewColumnDefinitions(ID, RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, IsLongitude, IsLatitude, DisplayFormat, Width, LanguageLabelId, TopHeaderCategory, TopHeaderCategoryOrder) VALUES (1032, 1, '1fb99efd-c69a-4495-966a-1a57dd3d43e7', N'Account', 0, 34, 0, 0, 0, 0, 0, 0, N'', N'', 2742, N'', 0)
GO
SET IDENTITY_INSERT SUserInterface.GridViewColumnDefinitions OFF
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Reseed identity on SUserInterface.GridViewColumnDefinitions
--
DBCC CHECKIDENT('SUserInterface.GridViewColumnDefinitions', RESEED, 1032)
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Updating data of table [SUserInterface].[GridViewDefinitions]
--

UPDATE SUserInterface.GridViewDefinitions SET DisplayOrder = 333 WHERE ID = 39
UPDATE SUserInterface.GridViewDefinitions SET DisplayOrder = 444 WHERE ID = 40
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	ID,
		Guid,
		RowStatus,
		Number,
		RealNet AS Net,
		RealVat AS Vat,
		RealGross AS Gross,
		RealOutstanding AS Outstanding,
		Date,
		Type,
		Surveyor,
SageTransactionReference
FROM	SJob.tvf_JobTransactions([[UserId]], ''[[ParentGuid]]'') root_hobt' WHERE ID = 89
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	ID,
		RowStatus,
		RowVersion,
		Guid,
		JobType,
		Quote,
		QuoteNet,
		StartRibaStage,
		EndRibaStage ,
QuoteStatus
FROM	SSop.tvf_EnquiryServices([[UserId]], ''[[ParentGuid]]'') root_hobt' WHERE ID = 103
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.CreatedDateTime,
		root_hobt.TotalRibaStageChange,
		root_hobt.FeeCapChange,
		root_hobt.FullName,
               root_hobt.TotalMeetingChange,
               root_hobt.TotalVisitChange
FROM	SJob.tvf_FeeAmendments([[UserId]], ''[[ParentGuid]]'') root_hobt' WHERE ID = 114
UPDATE SUserInterface.GridViewDefinitions SET DisplayOrder = 5 WHERE ID = 120
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	ID,
		RowStatus,
		RowVersion,
		Guid,
		Number,
		ExternalReference,
		DescriptionOfWorks,
		ClientAgentAccount,
                uprn,
                EnquiryStatus,
                Disciplines,
                Property,
               OrgUnit
FROM	SSop.tvf_Enquiries([[UserId]]) root_hobt' WHERE ID = 126
UPDATE SUserInterface.GridViewDefinitions SET MetricSqlQuery = N'SELECT CONVERT(DECIMAL(9,2), COUNT(1)) AS MetricValue1, N''#ff0000'' Value1ColourHex, 
CONVERT(DECIMAL(9,2), 0) AS MetricValue2, N''#0000ff'' Value2ColourHex FROM SJob.tvf_Jobs_TeamDormant([[UserId]]) ' WHERE ID = 133
UPDATE SUserInterface.GridViewDefinitions SET DetailPageUri = N'' WHERE ID = 139
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT  root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.Guid,
		root_hobt.Type,
		root_hobt.EntityTypeId,
		root_hobt.SortOrder,
		root_hobt.Label
FROM    SUserInterface.tvf_ActionMenuItems([[UserId]], ''[[ParentGuid]]'') root_hobt' WHERE ID = 144
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.TableName,
		root_hobt.LinkedEntityType
FROM	SCore.tvf_MergeDocumentTables([[UserId]], ''[[ParentGuid]]'') root_hobt' WHERE ID = 152
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT
     root_hobt.ID,
     root_hobt.RowStatus,
     root_hobt.Guid,
     root_hobt.Notes,
     root_hobt.CreatedDateTimeUTC,
     root_hobt.RequesterUserId,
     root_hobt.JobId,
     root_hobt.SurveyorName,
     root_hobt.Number,
     root_hobt.FinanceAccountID,
     -- [CBLD-522]
     root_hobt.ActivityId,               
    -- [CBLD-525]
     root_hobt.ClientName,
     root_hobt.Net,
     root_hobt.EndDate,
     root_hobt.JobBillingInstruction,
     root_hobt.CRMBillingInstruction,
     root_hobt.IsBillable
FROM
      [SFin].[tvf_InvoiceRequests]([[UserId]]) root_hobt' WHERE ID = 168
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT 
          root_hobt.ID,
          root_hobt.RowStatus,
          root_hobt.RowVersion,
          root_hobt.Guid,
          root_hobt.Notes,
          root_hobt.CreatedDateTimeUTC,
          root_hobt.RequesterUserId,
          root_hobt.JobId,
          root_hobt.IsProcessed
FROM
         SFin.tvf_JobInvoiceRequests(''[[ParentGuid]]'', [[UserId]]) root_hobt
         
' WHERE ID = 169
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT root_hobt.ID,
             root_hobt.RowStatus,
             root_hobt.RowVersion,
             root_hobt.Guid,
             root_hobt.DirectoryId,
             root_hobt.Code,
             root_hobt.Name
FROM Score.Groups root_hobt' WHERE ID = 173
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	ID,
		RowStatus,
		RowVersion,
		Guid,
		Role,
		Account,
		Contact 
FROM	[SSop].[tvf_ProjectDirectory] ([[UserId]], ''[[ParentGuid]]'') root_hobt' WHERE ID = 174
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	ID,
		RowStatus,
		RowVersion,
		Guid,
		Role,
		Account,
		Contact 
FROM	[SSop].[tvf_EnquiryProjectDirectory] ([[UserId]], ''[[ParentGuid]]'') root_hobt' WHERE ID = 175
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	ID,
		RowStatus,
		RowVersion,
		Guid,
		Role,
		Account,
		Contact 
FROM	[SSop].[tvf_QuoteProjectDirectory] ([[UserId]], ''[[ParentGuid]]'') root_hobt' WHERE ID = 176
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT root_hobt.[ID]
      ,root_hobt.[Guid]
      ,root_hobt.[RowStatus]
      ,root_hobt.[Name]
      ,root_hobt.[IsImageType]
FROM [SCore].[MergeDocumentItemTypes] root_hobt
WHERE	(root_hobt.id > 0)' WHERE ID = 177
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.Guid,
		root_hobt.MergeDocumentItemType,
		root_hobt.BookmarkName, 
		root_hobt.EntityType,
		root_hobt.SubFolderPath,
		root_hobt.ImageColumns
FROM	[SCore].[tvf_MergeDocumentItems]([[UserId]], ''[[ParentGuid]]'') root_hobt
WHERE   root_hobt.ID <> -1' WHERE ID = 178
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.Guid,
		root_hobt.SortOrder,
		root_hobt.SourceDocumentEntityProperty,
		root_hobt.SourceSharePointItemEntityProperty,
		root_hobt.IncludedMergeDocument,
		root_hobt.MergeDocumentItemGuid
FROM	[SCore].[tvf_MergeDocumentItemIncludes]([[UserId]], ''[[ParentGuid]]'') root_hobt' WHERE ID = 179
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	ID,
		RowStatus,
		RowVersion,
		Guid,
		DateTime,
		Detail
FROM	SSop.tvf_ProjectKeyDates([[UserId]], ''[[ParentGuid]]'') AS root_hobt' WHERE ID = 180
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	ID,
		Guid,
		RowStatus,
		RowVersion,
		Number,
		ExternalReference,
		JobStatus
FROM	SSop.tvf_EnquiryCreatedJobs ([[UserId]], ''[[ParentGuid]]'') root_hobt' WHERE ID = 181
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Item
FROM	[SSop].[tvf_ScheduleOfClientInformation] ([[UserId]], ''[[ParentGuid]]'') root_hobt' WHERE ID = 182
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.MergeFieldName,
		root_hobt.Label,
		root_hobt.HelpText	
FROM	SCore.tvf_MergeDocumentFieldReference([[UserId]], ''[[ParentGuid]]'') AS root_hobt' WHERE ID = 183
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.MergeFieldName,
		root_hobt.BookmarkName,
		root_hobt.MDItemsGuid,
		root_hobt.MDItems_EntityTypeID,
		root_hobt.Label,
		root_hobt.HelpText
FROM	SCore.tvf_MergeDocumentItemsFieldReference([[UserId]], ''[[ParentGuid]]'') AS root_hobt' WHERE ID = 184
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT root_hobt.ID,
	   root_hobt.RowStatus,
	   root_hobt.Guid,
	   root_hobt.Code,
	   root_hobt.Name,
	   root_hobt.AccountStatusName,
	   root_hobt.RelationshipManagerName,
	   root_hobt.MainAddress,
	   root_hobt.MainContact 
FROM	SCrm.tvf_Accounts ([[UserId]]) root_hobt
WHERE (root_hobt.ID > 0) And  root_hobt.Code <> ''''' WHERE ID = 185
UPDATE SUserInterface.GridViewDefinitions SET SqlQuery = N'SELECT
                root_hobt.ID,
                root_hobt.Guid,
                root_hobt.RowStatus,

		--[PROJECT]
		root_hobt.projectRef,						
		root_hobt.clientAgent,						
		root_hobt.propertyName ,					
		root_hobt.CDMRole,							
		root_hobt.jobStatus,						

		--[FINANCE]
		root_hobt.totalAgreed,
		root_hobt.totalRemaining,

		--[AGREED DELIVERABLES]
		root_hobt.preconMeetings,
		root_hobt.conMeetings,
		root_hobt.complianceVisit,
		root_hobt.hsFile,

		--[REMAINING DELIVERABLES]
		root_hobt.preconMeetingsRemaining,
		root_hobt.conMeetingsRemaining,
		root_hobt.compVisitsRemaining,
		root_hobt.HSIssued,

		--[NO HEADER] => [ Client Duties Issued + CDM Strategy Issued]
		root_hobt.clientDutiesIssued,
		root_hobt.CDMStrategyIssued,

		--[PCI]
		root_hobt.PCIInspectionCompleted,
		root_hobt.PCIDate,


		--[RISK]
		root_hobt.DRRLastIssued,

		--[F10]
		root_hobt.F10Applicable,
		root_hobt.F10IssuedDate,
		root_hobt.F10Start,
		root_hobt.F10WeekDuration,
		root_hobt.F10ExpiryDate,

		--[CPP]
		root_hobt.CPPDateReceived,
		root_hobt.CPPReviewed,			


		--[PROGRAMME]


		--[H&S File]
		root_hobt.HSFReviewed,
		root_hobt.HSFCompleted


FROM	SJob.tvf_Jobs_CDM_MyProjects ([[UserId]]) root_hobt' WHERE ID = 186

--
-- Inserting data into table [SUserInterface].[GridViewDefinitions]
--
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
SET IDENTITY_INSERT SUserInterface.GridViewDefinitions ON
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
INSERT SUserInterface.GridViewDefinitions(ID, RowStatus, Guid, Code, GridDefinitionId, DetailPageUri, SqlQuery, DefaultSortColumnName, SecurableCode, DisplayOrder, DisplayGroupName, MetricSqlQuery, ShowMetric, IsDetailWindowed, EntityTypeID, MetricTypeID, MetricMin, MetricMax, MetricMinorUnit, MetricMajorUnit, MetricStartAngle, MetricEndAngle, MetricReversed, MetricRange1Min, MetricRange1Max, MetricRange1ColourHex, MetricRange2Min, MetricRange2Max, MetricRange2ColourHex, IsDefaultSortDescending, AllowNew, AllowExcelExport, AllowPdfExport, AllowCsvExport, LanguageLabelId, DrawerIconId, GridViewTypeId, AllowBulkChange) VALUES (187, 1, 'ae9ea545-9698-4299-baef-7d46935faff0', N'ACCOUNTSWITHSAGECODE', 19, N'AccountDetail', N'SELECT root_hobt.ID,
	   root_hobt.RowStatus,
	   root_hobt.Guid,
	   root_hobt.Code,
	   root_hobt.Name,
	   root_hobt.AccountStatusName,
	   root_hobt.RelationshipManagerName,
	   root_hobt.MainAddress,
	   root_hobt.MainContact 
FROM	SCrm.tvf_AccountsWithSageCode ([[UserId]]) root_hobt
WHERE (root_hobt.ID > 0)', N'Name', N'', 2, N'', N'', 0, 1, 18, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'', 0, 0, N'', 1, 1, 0, 0, 0, 2822, -1, 1, 0)
GO
SET IDENTITY_INSERT SUserInterface.GridViewDefinitions OFF
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Reseed identity on SUserInterface.GridViewDefinitions
--
DBCC CHECKIDENT('SUserInterface.GridViewDefinitions', RESEED, 187)
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[EntityProperties]
--
ALTER TABLE SCore.EntityProperties WITH NOCHECK
  ADD CONSTRAINT FK_EntityProperties_DropDownListDefinitions FOREIGN KEY (DropDownListDefinitionID) REFERENCES SUserInterface.DropDownListDefinitions(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SCore.EntityProperties WITH NOCHECK
  ADD CONSTRAINT FK_EntityProperties_EntityDataTypes FOREIGN KEY (EntityDataTypeID) REFERENCES SCore.EntityDataTypes(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SCore.EntityProperties WITH NOCHECK
  ADD CONSTRAINT FK_EntityProperties_EntityHoBTs FOREIGN KEY (EntityHoBTID) REFERENCES SCore.EntityHobts(ID) ON DELETE CASCADE ON UPDATE NO ACTION
ALTER TABLE SCore.EntityProperties WITH NOCHECK
  ADD CONSTRAINT FK_EntityProperties_EntityPropertyGroupID FOREIGN KEY (EntityPropertyGroupID) REFERENCES SCore.EntityPropertyGroups(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SCore.EntityProperties WITH NOCHECK
  ADD CONSTRAINT FK_EntityProperties_LanguageLabels FOREIGN KEY (LanguageLabelID) REFERENCES SCore.LanguageLabels(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SCore.EntityProperties WITH NOCHECK
  ADD CONSTRAINT FK_EntityProperties_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[EntityQueries]
--
ALTER TABLE SCore.EntityQueries WITH NOCHECK
  ADD CONSTRAINT FK_EntityQueries_EntityHoBTs FOREIGN KEY (EntityHoBTID) REFERENCES SCore.EntityHobts(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SCore.EntityQueries WITH NOCHECK
  ADD CONSTRAINT FK_EntityQueries_EntityTypes FOREIGN KEY (EntityTypeID) REFERENCES SCore.EntityTypes(ID) ON DELETE CASCADE ON UPDATE NO ACTION
ALTER TABLE SCore.EntityQueries WITH NOCHECK
  ADD CONSTRAINT FK_EntityQueries_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[LanguageLabels]
--
ALTER TABLE SCore.LanguageLabels WITH NOCHECK
  ADD CONSTRAINT FK_LanguageLabels_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[LanguageLabelTranslations]
--
ALTER TABLE SCore.LanguageLabelTranslations WITH NOCHECK
  ADD CONSTRAINT FK_LanguageLabelTranslations_LanguageLabels FOREIGN KEY (LanguageLabelID) REFERENCES SCore.LanguageLabels(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SCore.LanguageLabelTranslations WITH NOCHECK
  ADD CONSTRAINT FK_LanguageLabelTranslations_Languages FOREIGN KEY (LanguageID) REFERENCES SCore.Languages(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SCore.LanguageLabelTranslations WITH NOCHECK
  ADD CONSTRAINT FK_LanguageLabelTranslations_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SUserInterface].[DropDownListDefinitions]
--
ALTER TABLE SUserInterface.DropDownListDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_DropDownListDefinitions_EntityTypes FOREIGN KEY (EntityTypeId) REFERENCES SCore.EntityTypes(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SUserInterface.DropDownListDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_DropDownListDefinitions_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SUserInterface].[GridViewColumnDefinitions]
--
ALTER TABLE SUserInterface.GridViewColumnDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_GridViewColumnDefinition_GridViewDefinition FOREIGN KEY (GridViewDefinitionId) REFERENCES SUserInterface.GridViewDefinitions(ID) ON DELETE CASCADE ON UPDATE NO ACTION
ALTER TABLE SUserInterface.GridViewColumnDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_GridViewColumnDefinitions_LanguageLabelId FOREIGN KEY (LanguageLabelId) REFERENCES SCore.LanguageLabels(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SUserInterface.GridViewColumnDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_GridViewColumnDefinitions_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SUserInterface].[GridViewDefinitions]
--
ALTER TABLE SUserInterface.GridViewDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_GridViewDefinition_GridDefinition FOREIGN KEY (GridDefinitionId) REFERENCES SUserInterface.GridDefinitions(ID) ON DELETE CASCADE ON UPDATE NO ACTION
ALTER TABLE SUserInterface.GridViewDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_GridViewDefinitions_DrawerIconId FOREIGN KEY (DrawerIconId) REFERENCES SUserInterface.Icons(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SUserInterface.GridViewDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_GridViewDefinitions_EntityTypes FOREIGN KEY (EntityTypeID) REFERENCES SCore.EntityTypes(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SUserInterface.GridViewDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_GridViewDefinitions_LanguageLabelId FOREIGN KEY (LanguageLabelId) REFERENCES SCore.LanguageLabels(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SUserInterface.GridViewDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_GridViewDefinitions_MetricTypes FOREIGN KEY (MetricTypeID) REFERENCES SUserInterface.MetricTypes(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
ALTER TABLE SUserInterface.GridViewDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_GridViewDefinitions_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[EntityPropertyActions]
--
ALTER TABLE SCore.EntityPropertyActions WITH NOCHECK
  ADD CONSTRAINT FK_EntityPropertyActions_EntityProperties FOREIGN KEY (EntityPropertyID) REFERENCES SCore.EntityProperties(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[EntityPropertyDependants]
--
ALTER TABLE SCore.EntityPropertyDependants WITH NOCHECK
  ADD CONSTRAINT FK_EntityPropertyDependants_EntityProperties FOREIGN KEY (ParentEntityPropertyID) REFERENCES SCore.EntityProperties(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[EntityQueryParameters]
--
ALTER TABLE SCore.EntityQueryParameters WITH NOCHECK
  ADD CONSTRAINT FK_EntityQueryParameters_EntityProperties FOREIGN KEY (MappedEntityPropertyID) REFERENCES SCore.EntityProperties(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[MergeDocumentItemIncludes]
--
ALTER TABLE SCore.MergeDocumentItemIncludes WITH NOCHECK
  ADD CONSTRAINT FK_MergeDocumentItemIncludes_EntityProperties FOREIGN KEY (SourceDocumentEntityPropertyId) REFERENCES SCore.EntityProperties(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[RecordHistory]
--
ALTER TABLE SCore.RecordHistory WITH NOCHECK
  ADD CONSTRAINT FK_RecordHistory_EntityPropertyID FOREIGN KEY (EntityPropertyID) REFERENCES SCore.EntityProperties(ID) ON DELETE CASCADE ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[SynchronisationErrors]
--
ALTER TABLE SCore.SynchronisationErrors WITH NOCHECK
  ADD CONSTRAINT FK_SychronisationErrors_EntityPropertyID FOREIGN KEY (EntityPropertyID) REFERENCES SCore.EntityProperties(ID) ON DELETE CASCADE ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SUserInterface].[ActionMenuItems]
--
ALTER TABLE SUserInterface.ActionMenuItems WITH NOCHECK
  ADD CONSTRAINT FK_ActionMenuItems_EntityQueries FOREIGN KEY (EntityQueryId) REFERENCES SCore.EntityQueries(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SUserInterface].[GridViewActions]
--
ALTER TABLE SUserInterface.GridViewActions WITH NOCHECK
  ADD CONSTRAINT FK_GridViewActions_EntityQueries FOREIGN KEY (EntityQueryId) REFERENCES SCore.EntityQueries(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SUserInterface].[GridViewWidgetQueries]
--
ALTER TABLE SUserInterface.GridViewWidgetQueries WITH NOCHECK
  ADD CONSTRAINT FK_GridViewWidgetQueries_EntityQueries FOREIGN KEY (EntityQueryId) REFERENCES SCore.EntityQueries(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[EntityPropertyGroups]
--
ALTER TABLE SCore.EntityPropertyGroups WITH NOCHECK
  ADD CONSTRAINT FK_EntityPropertyGroups_LanguageLabels FOREIGN KEY (LanguageLabelID) REFERENCES SCore.LanguageLabels(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SCore].[EntityTypes]
--
ALTER TABLE SCore.EntityTypes WITH NOCHECK
  ADD CONSTRAINT FK_EntityTypes_LanguageLabels FOREIGN KEY (LanguageLabelID) REFERENCES SCore.LanguageLabels(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SUserInterface].[GridDefinitions]
--
ALTER TABLE SUserInterface.GridDefinitions WITH NOCHECK
  ADD CONSTRAINT FK_GridDefinitions_LanguageLabelId FOREIGN KEY (LanguageLabelId) REFERENCES SCore.LanguageLabels(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Creating constraints for [SUserInterface].[MainMenuItems]
--
ALTER TABLE SUserInterface.MainMenuItems WITH NOCHECK
  ADD CONSTRAINT FK_MainMenuItems_LanguageLabelId FOREIGN KEY (LanguageLabelId) REFERENCES SCore.LanguageLabels(ID) ON DELETE NO ACTION ON UPDATE NO ACTION
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Enabling DML triggers for [SCore].[EntityProperties]
--
GO
ENABLE TRIGGER ALL ON SCore.EntityProperties
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Enabling DML triggers for [SCore].[EntityQueries]
--
GO
ENABLE TRIGGER ALL ON SCore.EntityQueries
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Enabling DML triggers for [SCore].[LanguageLabels]
--
GO
ENABLE TRIGGER ALL ON SCore.LanguageLabels
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Enabling DML triggers for [SCore].[LanguageLabelTranslations]
--
GO
ENABLE TRIGGER ALL ON SCore.LanguageLabelTranslations
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Enabling DML triggers for [SUserInterface].[DropDownListDefinitions]
--
GO
ENABLE TRIGGER ALL ON SUserInterface.DropDownListDefinitions
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

UPDATE SUserInterface.GridViewDefinitions SET DisplayOrder = 3 WHERE ID = 39
UPDATE SUserInterface.GridViewDefinitions SET DisplayOrder = 4 WHERE ID = 40
GO 


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





ALTER PROCEDURE [SSop].[QuotesRevise] @SourceGuid UNIQUEIDENTIFIER,
								  @TargetGuid UNIQUEIDENTIFIER
AS
BEGIN

	DECLARE @SourceID INT,
			@ID		  INT,
			@IsInsert BIT;

	SELECT	@SourceID = ID
	FROM	SSop.Quotes
	WHERE	(Guid = @SourceGuid);

	IF (@@ROWCOUNT > 1)
	BEGIN
		;
		THROW 60000, N'Invalid source Quote', 1;
	END;

	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SSop.Quotes AS q
		 WHERE	(q.Guid = @SourceGuid)
			AND (q.DateAccepted IS NOT NULL)
	 )
	   )
	BEGIN
		; THROW 60000, N'You cannot revise an accepted quote', 1;
	END;

	EXEC SCore.UpsertDataObject @Guid = @TargetGuid,
								@SchemeName = N'SSop',
								@ObjectName = N'Quotes',
								@IncludeDefaultSecurity = 1,
								@IsInsert = @IsInsert;

	INSERT	SSop.Quotes
		 (RowStatus,
		  Guid,
		  OrganisationalUnitID,
		  QuotingUserId,
		  Number,
		  UprnId,
		  ClientAccountId,
		  ClientAddressId,
		  ClientContactId,
		  ContractID,
		  Date,
		  Overview,
		  ExpiryDate,
		  QuoteSourceId,
		  IsSubjectToNDA,
		  AgentAccountId,
		  AgentAddressId,
		  AgentContactId,
		  ExternalReference,
		  FeeCap,
		  RevisionNumber,
		  OriginalQuoteId,
		  EnquiryServiceID,
		  DescriptionOfWorks,
		  QuotingConsultantId,
		  ExclusionsAndLimitations,
		  ProjectId)
	SELECT	0,
			@TargetGuid,
			q.OrganisationalUnitID,
			q.QuotingUserId,
			q.Number,
			q.UprnId,
			q.ClientAccountId,
			q.ClientAddressId,
			q.ClientContactId,
			q.ContractID,
			GETDATE (),
			q.Overview,
			DATEADD (	MONTH,
						6,
						GETDATE ()
					),
			q.QuoteSourceId,
			q.IsSubjectToNDA,
			q.AgentAccountId,
			q.AgentAddressId,
			q.AgentContactId,
			q.ExternalReference,
			q.FeeCap,
			ISNULL (   latest_revision.rev,
					   0
				   ) + 1,
			CASE
				WHEN q.OriginalQuoteId = (-1) THEN q.ID
				ELSE q.OriginalQuoteId
			END,
			q.EnquiryServiceID,
			q.DescriptionOfWorks,
			q.QuotingConsultantId,
			q.ExclusionsAndLimitations,
			q.ProjectId
	FROM	SSop.Quotes AS q
	OUTER APPLY
			(
				SELECT	MAX (q1.RevisionNumber) AS rev
				FROM	SSop.Quotes AS q1
				WHERE	(q1.OriginalQuoteId = CASE
												  WHEN q.OriginalQuoteId = (-1) THEN q.ID
												  ELSE q.OriginalQuoteId
											  END
						)
			)			AS latest_revision
	WHERE	(q.ID = @SourceID);

	SELECT	@ID = SCOPE_IDENTITY ();


	-- Build the collection of items to duplicate. 
	DECLARE @QuoteItems SCore.TwoGuidUniqueList;

	INSERT	@QuoteItems
		 (GuidValue, GuidValueTwo)
	SELECT	qi.Guid,
			NEWID ()
	FROM	SSop.QuoteItems AS qi
	WHERE	(qi.QuoteId = @SourceID)
		AND (qi.RowStatus NOT IN (0, 254));

	-- Build the collection of payment stages to duplicate
	DECLARE @QuotePaymentStages SCore.TwoGuidUniqueList;

	INSERT	@QuotePaymentStages
		 (GuidValue, GuidValueTwo)
	SELECT	qps.Guid,
			NEWID ()
	FROM	SSop.QuotePaymentStages AS qps
	WHERE	(qps.QuoteId = @SourceID)
		AND (qps.RowStatus NOT IN (0, 254));

	-- Build the collection of quote memos
	DECLARE @QuoteMemos SCore.TwoGuidUniqueList;

	INSERT	@QuoteMemos --RETURNS NOTHING
		 (GuidValue, GuidValueTwo)
	SELECT	qm.Guid,
			NEWID ()
	FROM	SSop.QuoteMemos AS qm
	WHERE	(qm.QuoteID = @SourceID)
		AND (qm.RowStatus NOT IN (0, 254));

	-- Create the data objects. 
	DECLARE @NewGuidList SCore.GuidUniqueList;

	INSERT	@NewGuidList
		 (GuidValue)
	SELECT	GuidValueTwo
	FROM	@QuoteItems;

	EXEC SCore.DataObjectBulkUpsert @GuidList = @NewGuidList,		-- GuidUniqueList
									@SchemeName = N'SSop',			-- nvarchar(255)
									@ObjectName = N'QuoteItems',	-- nvarchar(255)
									@IsInsert = @IsInsert OUTPUT;	-- bit	

	DELETE	FROM @NewGuidList;
	INSERT	@NewGuidList
		 (GuidValue)
	SELECT	GuidValueTwo
	FROM	@QuotePaymentStages;

	EXEC SCore.DataObjectBulkUpsert @GuidList = @NewGuidList,				-- GuidUniqueList
									@SchemeName = N'SSop',					-- nvarchar(255)
									@ObjectName = N'QuotePaymentStages',	-- nvarchar(255)
									@IsInsert = @IsInsert OUTPUT;			-- bit	

	DELETE	FROM @NewGuidList;
	INSERT	@NewGuidList
		 (GuidValue)
	SELECT	qm.GuidValueTwo
	FROM	@QuoteMemos AS qm;

	EXEC SCore.DataObjectBulkUpsert @GuidList = @NewGuidList,		-- GuidUniqueList
									@SchemeName = N'SSop',			-- nvarchar(255)
									@ObjectName = N'QuoteMemos',	-- nvarchar(255)
									@IsInsert = @IsInsert OUTPUT;	-- bit	

	-- Duplicate the Quote Items. 
	INSERT	SSop.QuoteItems
		 (RowStatus, Guid, QuoteId, ProductId, Details, Net, VatRate, DoNotConsolidateJob, SortOrder, Quantity)
	SELECT	1,
			qil.GuidValueTwo,
			@ID,
			qi.ProductId,
			qi.Details,
			qi.Net,
			qi.VatRate,
			qi.DoNotConsolidateJob,
			qi.SortOrder,
			qi.Quantity
	FROM	SSop.QuoteItems	   AS qi
	JOIN	@QuoteItems		   AS qil ON (qil.GuidValue = qi.Guid)
	JOIN	SSop.QuoteSections AS oqs ON (oqs.ID		= qi.QuoteSectionId);


	-- Duplicate the Quote Payment Stages 
	INSERT INTO SSop.QuotePaymentStages
		 (RowStatus, Guid, QuoteId, PaymentFrequencyTypeId, PaymentFrequency, Value, PercentageOfTotal, PayAfterStageId)
	SELECT	1,
			qpsl.GuidValueTwo,
			@ID,
			qps.PaymentFrequencyTypeId,
			qps.PaymentFrequency,
			qps.Value,
			qps.PercentageOfTotal,
			qps.PayAfterStageId
	FROM	SSop.QuotePaymentStages AS qps
	JOIN	@QuotePaymentStages		AS qpsl ON (qps.Guid = qpsl.GuidValue);

	-- Duplicate the Quote Memos
	INSERT INTO SSop.QuoteMemos
		 (RowStatus, Guid, QuoteID, Memo, CreatedDateTimeUTC, CreatedByUserId)
	SELECT	1,
			qms.GuidValueTwo,
			@ID,
			qm.Memo,
			qm.CreatedDateTimeUTC,
			qm.CreatedByUserId
	FROM	SSop.QuoteMemos AS qm
	JOIN	@QuoteMemos		AS qms ON (qm.Guid = qms.GuidValue);

	UPDATE	SSop.Quotes
	SET		RowStatus = 1
	WHERE	(ID = @ID);
END;


-- ROLLBACK TRAN 

-- commit tran 
-- SET NOEXEC OFF




