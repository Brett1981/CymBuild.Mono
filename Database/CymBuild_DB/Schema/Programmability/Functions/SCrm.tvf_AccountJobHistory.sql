SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_AccountJobHistory]
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
		jt.Name AS JobTypeName,
		i.FullName AS Surveyor
FROM    SJob.Jobs j
JOIN	SJob.JobTypes jt ON (jt.ID = j.JobTypeID)
JOIN	SCrm.Accounts a ON (a.ID = j.ClientAccountID) OR (a.ID = j.AgentAccountID) OR (a.ID = j.FinanceAccountID)
JOIN	SCore.Identities i ON (i.ID = j.SurveyorID)
WHERE   (a.RowStatus NOT IN (0, 254))
	AND	(a.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
	AND	(a.Guid = @ParentGuid)
GO