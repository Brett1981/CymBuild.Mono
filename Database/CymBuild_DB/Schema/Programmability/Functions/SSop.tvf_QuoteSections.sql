SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_QuoteSections]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
RETURN SELECT		qs.ID,
					qs.RowStatus,
					qs.RowVersion,
					qs.Guid,
					qs.SortOrder,
					qs.Name,
					rs.Number AS RibaStage,
					qst.Net,
					qst.Gross
	   FROM			SSop.QuoteSections			  AS qs
	   JOIN			SSop.Quotes					  AS q ON (q.ID = qs.QuoteId)
	   LEFT JOIN	SSop.QuoteSectionTotals		  AS qst ON (qst.ID = qs.ID)
	   JOIN			SJob.RibaStages				  AS rs ON (rs.ID = qs.RibaStageId)
	   WHERE		(qs.RowStatus NOT IN (0, 254))
				AND (qs.ID		> 0)
AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(qs.Guid, @UserId) oscr
			)
		)
				AND (q.Guid		= @ParentGuid)
	   UNION ALL
	   SELECT		-2,
					1,
					q.RowVersion,
					q.Guid,
					999,
					N'Total',
					0,
					SUM (ISNULL (	qst.Net,
									0
								)
						),
					SUM (ISNULL (	qst.Gross,
									0
								)
						)
	   FROM			SSop.QuoteSections		AS qs
	   JOIN			SSop.Quotes				AS q ON (q.ID	  = qs.QuoteId)
	   LEFT JOIN	SSop.QuoteSectionTotals AS qst ON (qst.ID = qs.ID)
	   WHERE		(qs.RowStatus NOT IN (0, 254))
				AND (qs.ID		> 0)
				AND (q.Guid		= @ParentGuid)
		GROUP BY	q.RowVersion, q.Guid
GO