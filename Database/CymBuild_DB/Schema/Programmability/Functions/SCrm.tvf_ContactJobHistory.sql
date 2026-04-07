SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_ContactJobHistory]
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
JOIN	SCrm.Contacts c ON (c.ID = j.ClientContactID) OR (c.Id = j.AgentContactID) OR (c.Id = j.FinanceContactID)
JOIN	SCore.Identities i ON (i.ID = j.SurveyorID)
WHERE   (c.RowStatus NOT IN (0, 254))
	AND	(c.ID > 0)
	AND	(c.Guid = @ParentGuid)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
GO