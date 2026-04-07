SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_Quotes_CreatedJobs] 
(
	@ParentGuid UNIQUEIDENTIFIER,
    @UserId INT
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN 
SELECT  j.ID,
        j.RowStatus,
        j.RowVersion,
        j.Guid,
        j.Number,
        j.JobDescription,
        j.JobTypeID,
        jt.Name AS JobTypeName,
		i.Guid SurveyorGuid,
		i.FullName AS SurveyorName, 
		j.IsComplete,
		js.JobStatus
FROM    SJob.Jobs j
JOIN	SJob.JobStatus js ON (js.ID = j.ID)
JOIN    SJob.JobTypes jt ON (j.JobTypeID = jt.ID)
JOIN    SCore.Identities i ON (j.SurveyorID = i.ID)
WHERE   (j.RowStatus  NOT IN (0, 254))
	AND	(j.Id > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
	AND	(EXISTS 
			(
				SELECT	1
				FROM	SSop.QuoteItems qi
				JOIN	SSop.Quotes q ON (q.ID = qi.QuoteId)
				WHERE	(q.Guid = @ParentGuid)
					AND	(qi.CreatedJobId = j.ID) 
			)
		)
GO