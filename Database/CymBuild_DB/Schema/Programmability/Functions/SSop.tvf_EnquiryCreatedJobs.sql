SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_EnquiryCreatedJobs]
(
	@UserID INT,
	@EnquiryGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
	-- --WITH SCHEMABINDING
AS
RETURN 
SELECT	j.ID, 
		j.Guid, 
		j.RowStatus,
		j.RowVersion,
		j.Number,
		j.ExternalReference,
		js.JobStatus
FROM	SJob.Jobs AS j
JOIN	SJob.JobStatus AS js ON (js.ID = j.ID)
WHERE	(j.RowStatus NOT IN (0, 254))
	AND	(j.ID > 0)
	AND	(EXISTS 
			(
				SELECT	1
				FROM	SSop.Enquiries AS e
				JOIN	SSop.EnquiryServices es ON (es.EnquiryId = e.ID)
				JOIN	SSop.Quotes q ON (q.EnquiryServiceID = es.ID)
				JOIN	SSop.QuoteItems qi ON (qi.QuoteId = q.ID)
				WHERE	(qi.CreatedJobId = j.ID)
					AND	(e.Guid = @EnquiryGuid)
			)
		)
GO