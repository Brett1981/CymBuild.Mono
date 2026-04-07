SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_CurrentJobs] 
(
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
		client.Name + N' / ' + agent.Name AS  ClientAgent,
		i.FullName AS SurveyorName, 
		prop.FormattedAddressComma,
		j.IsSubjectToNDA,
		j.IsComplete,
		js.JobStatus,
		org.Name AS OrgUnit,
		j.ExternalReference
FROM    SJob.Jobs j
JOIN	SJob.JobStatus js ON (js.ID = j.ID)
JOIN    SJob.JobTypes jt ON (j.JobTypeID = jt.ID)
JOIN    SCore.Identities i ON (j.SurveyorID = i.ID)
JOIN	SJob.Assets prop ON (prop.ID = j.UprnID)
JOIN	SCrm.Accounts client ON (client.ID = j.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = j.AgentAccountID)
JOIN    SCore.OrganisationalUnits as org ON (org.ID = j.OrganisationalUnitID)
WHERE   (j.RowStatus  NOT IN (0, 254))
	AND	(j.Id > 0)
	AND	(j.IsActive = 1)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
GO