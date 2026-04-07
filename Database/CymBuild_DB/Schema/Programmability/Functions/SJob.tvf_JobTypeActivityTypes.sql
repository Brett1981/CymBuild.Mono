SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobTypeActivityTypes] 
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
               --WITH SCHEMABINDING
AS
RETURN 
SELECT  jtat.ID,
        jtat.RowStatus, 
        jtat.RowVersion,
        jtat.Guid,
		ty.Name
FROM    SJob.JobTypeActivityTypes jtat
JOIN	SJob.ActivityTypes ty ON (ty.ID = jtat.ActivityTypeID)
JOIN	SJob.JobTypes jt ON (jt.ID = jtat.JobTypeID)
WHERE   (jtat.RowStatus  NOT IN (0, 254))
	AND (ty.RowStatus NOT IN (0,254))
    AND (jt.Guid = @ParentGuid)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(jtat.Guid, @UserId) oscr
			)
		)
GO