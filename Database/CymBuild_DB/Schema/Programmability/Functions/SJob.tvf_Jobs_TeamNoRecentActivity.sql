SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_TeamNoRecentActivity] 
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
		j.JobDescription AS Description, 
		client.Name + N' / ' + agent.Name AS ClientAgent,
		asset.FormattedAddressComma AS Asset,
		j.ExternalReference,
		 CASE 
            WHEN LastActivity.LastActivityChange IS NULL AND LastMilestone.LastMilestoneChange IS NULL THEN NULL --(return null if both are null)
            WHEN LastActivity.LastActivityChange IS NULL THEN LastMilestone.LastMilestoneChange					 
            WHEN LastMilestone.LastMilestoneChange IS NULL THEN LastActivity.LastActivityChange
            WHEN LastActivity.LastActivityChange > LastMilestone.LastMilestoneChange THEN LastActivity.LastActivityChange
            ELSE LastMilestone.LastMilestoneChange
        END AS LastActivityDate,
		jt.Name AS JobTypeName,
		i.FullName AS Consultant
FROM    
	SJob.Jobs  AS j
 
JOIN	
	SJob.Assets AS asset ON (asset.ID = j.UprnId)

JOIN
	SCrm.Accounts AS client ON (j.ClientAccountId = client.ID)
JOIN
	SCrm.Accounts AS agent ON (j.AgentAccountId = agent.ID)
JOIN
	SCore.Identities AS i		ON (j.SurveyorID = i.ID)
JOIN
	SJob.JobTypes as jt ON (jt.ID = j.JobTypeID)
--Retrieve date of last change for activities + milestones (60 >= days)
OUTER APPLY
(
    SELECT MAX(rh1.Datetime) AS LastActivityChange
    FROM SCore.RecordHistory AS rh1
    JOIN SJob.Activities AS a1 
        ON rh1.RowGuid = a1.Guid
    WHERE a1.JobID = j.ID
      AND a1.RowStatus NOT IN (0,254)
      AND rh1.RowStatus NOT IN (0,254)
) AS LastActivity
OUTER APPLY
(
    SELECT MAX(rh1.Datetime) AS LastMilestoneChange
    FROM SCore.RecordHistory AS rh1
    JOIN SJob.Milestones AS m1 
        ON rh1.RowGuid = m1.Guid
    WHERE m1.JobID = j.ID
      AND m1.RowStatus NOT IN (0,254)
      AND rh1.RowStatus NOT IN (0,254)
) AS LastMilestone
CROSS APPLY
	(
		SELECT	ou1.OrgNode
		FROM	SCore.OrganisationalUnits AS ou1
		JOIN	SCore.Identities		  AS i1 ON (i1.OriganisationalUnitId = ou1.ID)
		WHERE	(i1.ID = @UserId)
	) AS CurrentUser
WHERE   
	(j.RowStatus  NOT IN (0, 254)) 
	AND (j.IsActive = 1) 
	AND 
	(
		(j.IsComplete	= 0) AND  
		(NOT EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition 
			JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
			WHERE 
				DataObjectGuid = j.Guid AND wfs.Guid = '20D22623-283B-4088-9CEB-D944AC3E6516' ))
				
	)
				
	AND 
	(
		(j.IsCancelled	= 0) AND  
		(NOT EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition 
			JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
			WHERE 
				DataObjectGuid = j.Guid AND wfs.Guid = '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64' ))
				
	)
	AND 
	(
		(j.DeadDate	IS NULL) AND  
		(NOT EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition 
			JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
			WHERE 
				DataObjectGuid = j.Guid AND wfs.Guid = '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D' ))
				
	) 
	--Exclude if any activity has been updated in the last 60 days.
	AND NOT EXISTS (
		SELECT 1
		FROM SJob.Activities AS a
		WHERE a.JobID = j.ID
		  AND a.RowStatus NOT IN (0,254)
		  AND EXISTS (
			  SELECT 1
			  FROM SCore.RecordHistory AS rh
			  WHERE rh.RowGuid = a.Guid
				AND rh.RowStatus NOT IN (0,254)
				AND rh.Datetime >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
		  )
	)
	--Exclude if any milestone has been updated in the last 60 days.
	AND NOT EXISTS (
		SELECT 1
		FROM SJob.Milestones AS m
		WHERE m.JobID = j.ID
		  AND m.RowStatus NOT IN (0,254)
		  AND EXISTS (
			  SELECT 1
			  FROM SCore.RecordHistory AS rh
			  WHERE rh.RowGuid = m.Guid
				AND rh.RowStatus NOT IN (0,254)
				AND rh.Datetime >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
		  )
	)
	AND (EXISTS
		(
			SELECT	1
			FROM		SCore.ObjectSecurityForUser_CanRead (	j.Guid,
															@UserId
														) AS oscr
		)
			)
				
		AND (EXISTS
		(
			SELECT	1
			FROM		SCore.OrganisationalUnits AS ou2
			WHERE	(ou2.ID											  = i.OriganisationalUnitId)
				AND (ou2.OrgNode.IsDescendantOf (CurrentUser.OrgNode) = 1)
		)
				)
GO