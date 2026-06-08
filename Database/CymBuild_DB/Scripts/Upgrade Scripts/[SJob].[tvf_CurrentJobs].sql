USE [CymBuild_Dev]
GO

/****** Object:  UserDefinedFunction [SJob].[tvf_CurrentJobs]    Script Date: 11/05/2026 14:16:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER   FUNCTION [SJob].[tvf_CurrentJobs] 
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
OUTER APPLY
(
    SELECT TOP (1)
        ws.IsActiveStatus
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = j.Guid
      AND dot.RowStatus NOT IN (0, 254)
      AND ws.RowStatus NOT IN (0, 254)
      AND ws.ShowInJobs = 1
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
) AS latestStatus
WHERE   (j.RowStatus  NOT IN (0, 254))
	AND	(j.Id > 0)
	AND
    (
        CASE
            WHEN latestStatus.IsActiveStatus IS NULL THEN ISNULL(j.IsActive, 0)
            ELSE ISNULL(latestStatus.IsActiveStatus, 0)
        END
    ) = 1
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
GO


