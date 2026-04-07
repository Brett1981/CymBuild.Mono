SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_ProjectJobs]
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
		i.FullName AS Surveyor,
		js.JobStatus,
		jt.Name AS JobType,
		client.Name + N' / ' + agent.Name AS ClientAgent
FROM    SJob.Jobs j 
JOIN	SJob.JobStatus js ON (js.ID = j.ID)
JOIN	SJob.JobTypes jt ON (jt.ID = j.JobTypeID)
JOIN	SSop.Projects p ON (p.ID = j.ProjectId)
JOIN	SCore.Identities i ON (i.ID = j.SurveyorID)
JOIN	SCrm.Accounts client ON (client.ID = j.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = j.AgentAccountID)
WHERE   (j.RowStatus NOT IN (0, 254))
	AND	(p.Guid = @ParentGuid)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (j.guid, @UserId) oscr
			)
		)
GO