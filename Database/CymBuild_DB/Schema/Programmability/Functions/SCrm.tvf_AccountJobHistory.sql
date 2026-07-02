SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SCrm].[tvf_AccountJobHistory]')
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
		i.FullName AS Surveyor,
		org1.Name AS Department,
		org2.Name AS BusinessUnit
FROM    SJob.Jobs j
JOIN	SJob.JobTypes jt ON (jt.ID = j.JobTypeID)
JOIN	SCrm.Accounts a ON (a.ID = j.ClientAccountID) OR (a.ID = j.AgentAccountID) OR (a.ID = j.FinanceAccountID)
JOIN	SCore.Identities i ON (i.ID = j.SurveyorID)
LEFT JOIN
		SCore.OrganisationalUnits AS org1 ON (j.OrganisationalUnitID = org1.ID)
LEFT JOIN 
		SCore.OrganisationalUnits AS org2 ON (org1.ParentID = org2.ID)
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