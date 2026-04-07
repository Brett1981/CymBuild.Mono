SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_QuoteFeeDrawdown] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
       --WITH SCHEMABINDING
AS
RETURN 
SELECT		q.ID,
			q.RowStatus,
			q.Guid,
			CASE
				WHEN rs.Number = 0 THEN N'Fee Cap'
				WHEN rs.Number = 99 THEN N'Pre-Construction'
				WHEN rs.Number = 999 THEN N'Construction'
				ELSE CONVERT (	 NVARCHAR(10),
								 rs.Number
							 )
			END AS Stage,
			ISNULL(CASE rs.Number
				WHEN 0 THEN q.FeeCap
				ELSE stages.Net
			END, 0) AS Quoted
FROM		SSop.Quotes		AS q
CROSS JOIN	SJob.RibaStages AS rs
OUTER APPLY
			(
				SELECT		CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END  AS RibaStage,
							SUM(qit.LineNet) AS Net
				FROM		SSop.QuoteItems		AS qi
				JOIN		SSop.QuoteItemTotals AS qit ON (qi.ID = qit.ID)
				WHERE		(qi.QuoteId = q.ID)
						AND (qi.RowStatus NOT IN (0, 254))
						AND	(CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END = rs.ID)
				GROUP BY	CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END
			)				AS stages
WHERE		(rs.ID	> 0)
		AND (q.Guid = @ParentGuid)
		AND	(
				(
						(rs.IsRealStage = 1)
						AND	(NOT EXISTS
								(
									SELECT	1
									FROM	SSop.QuoteSections eqs
									JOIN	SJob.RibaStages ers ON (ers.ID = eqs.RibaStageId)
									WHERE	(eqs.QuoteId = q.ID)
										AND	(eqs.RowStatus NOT IN (0, 254))
										AND	(ers.Number IN (99, 999))
								)
							)
					)
				OR	(
						(rs.IsRealStage = 0)
						AND	(EXISTS
								(
									SELECT	1
									FROM	SSop.QuoteSections eqs
									JOIN	SJob.RibaStages ers ON (ers.ID = eqs.RibaStageId)
									WHERE	(eqs.QuoteId = q.ID)
										AND	(eqs.RowStatus NOT IN (0, 254))
										AND	(ers.Number IN (99, 999))
								)
							)
					)
			)
UNION ALL
SELECT	q.Id,
		q.RowStatus,
		q.Guid,
		N'Total (ex. Fee Cap.)',
		sections.Total AS Quoted
FROM	SSop.Quotes q
OUTER APPLY (
	SELECT SUM(qit.LineNet) AS Total
	FROM	SSop.QuoteItems  qi
	JOIN	SSop.QuoteItemTotals qit ON (qit.ID = qi.ID)
	WHERE	(qi.QuoteId = q.ID)
) AS sections
WHERE	(q.Guid = @ParentGuid)
UNION ALL
SELECT	q.Id,
		q.RowStatus,
		q.Guid,
		N'Total (inc. Fee Cap.)',
		sections.Total + q.FeeCap AS Quoted
FROM	SSop.Quotes q
OUTER APPLY (
	SELECT SUM(qit.LineNet) AS Total
	FROM	SSop.QuoteItems  qi
	JOIN	SSop.QuoteItemTotals qit ON (qit.ID = qi.ID)
	WHERE	(qi.QuoteId = q.ID)
) AS sections
WHERE	(q.Guid = @ParentGuid)

GO