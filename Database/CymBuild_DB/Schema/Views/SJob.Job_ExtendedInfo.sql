SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SJob].[Job_ExtendedInfo]
    --WITH SCHEMABINDING
AS
SELECT	j.Id,
		j.RowStatus,
		j.RowVersion,
		j.Guid,
		ISNULL(QuoteDetail.Guid, '00000000-0000-0000-0000-000000000000') AS QuoteGuid
FROM	SJob.Jobs j 
OUTER APPLY
(
	SELECT	q.ID,
			q.Guid
	FROM	SSop.Quotes q
	WHERE	(EXISTS
				(
					SELECT	1
					FROM	SSop.QuoteItems qi
					WHERE	(qi.QuoteId = q.Id)
						AND	(qi.CreatedJobId = j.ID)

				)
			)
) QuoteDetail
GO