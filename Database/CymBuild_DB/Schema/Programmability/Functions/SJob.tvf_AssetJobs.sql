SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO




CREATE FUNCTION [SJob].[tvf_AssetJobs] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
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
		i.FullName AS SurveyorName
FROM    SJob.Jobs j
JOIN	SJob.Assets p ON (p.ID = j.UprnID)
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
	AND	(p.Guid = @ParentGuid)
GO