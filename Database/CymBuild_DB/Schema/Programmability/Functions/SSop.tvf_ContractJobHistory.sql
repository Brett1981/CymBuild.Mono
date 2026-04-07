SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_ContractJobHistory]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  j.ID,
        j.RowStatus,
        j.RowVersion,
        j.Guid,
		j.Number,
		j.JobDescription,
		jt.Name AS JobTypeName
FROM    SJob.Jobs j
JOIN	SJob.JobTypes jt ON (jt.ID = j.JobTypeID)
JOIN	SSop.Contracts c ON (c.Id = j.ContractID)
WHERE   (c.RowStatus NOT IN (0, 254))
	AND	(c.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
	AND	(c.Guid = @ParentGuid)
GO