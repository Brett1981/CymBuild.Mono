SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_TeamDRRNeedsReview]
	(
		@UserId INT
	)
RETURNS TABLE
           --WITH SCHEMABINDING
AS
RETURN	SELECT 	j.ID,
				j.RowStatus,
				j.RowVersion,
				j.Guid,
				j.Number,
				j.JobDescription,
				j.JobTypeID,
				jt.Name						AS JobTypeName,
				i.Guid						AS SurveyorGuid,
				i.FullName					AS SurveyorName,
				client.Name + N' / ' + agent.Name AS ClientAgent,
				js.IsSubjectToNDA,
				j.ExternalReference,
				j.CreatedOn,
				assets.FormattedAddressComma AS Asset
	   FROM		SJob.Jobs			AS j
	   JOIN		SJob.JobStatus		AS js ON (js.ID = j.ID)
	   JOIN		SJob.JobTypes		AS jt ON (j.JobTypeID = jt.ID)
	   JOIN		SCore.Identities	AS i ON (j.SurveyorID = i.ID)
	   JOIN		SCrm.Accounts		AS client ON (client.ID = j.ClientAccountID)
	   JOIN		SCrm.Accounts		AS agent ON (agent.ID = j.AgentAccountID)
	   JOIN		SJob.Assets			AS assets ON (assets.ID = j.UprnID)
	   CROSS APPLY
				(
					SELECT	ou1.OrgNode
					FROM	SCore.OrganisationalUnits AS ou1
					JOIN	SCore.Identities		  AS i1 ON (i1.OriganisationalUnitId = ou1.ID)
					WHERE	(i1.ID = @UserId)
				) AS CurrentUser
	   WHERE	(j.RowStatus NOT IN (0, 254))
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
						SELECT 1 
						FROM SJob.Milestones AS m
						JOIN SJob.MilestoneTypes AS mt ON (mt.ID = m.MilestoneTypeID)
						WHERE 
							(m.JobID = j.ID) AND
							(mt.Code = N'DESIGNHAZ') AND
							(m.CompletedDateTimeUTC IS NULL) AND
							(m.IsNotApplicable = 0)
					)
				)
			
			AND 
			(
				(j.IsComplete	= 0) AND  
				(j.JobCompleted IS NULL) AND
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
			AND (j.IsActive				= 1)
			AND (j.IsPendingCompletion	= 0)
			AND (EXISTS
		   (
			   SELECT	1
			   FROM		SCore.OrganisationalUnits AS ou2
			   WHERE	(ou2.ID											  = i.OriganisationalUnitId)
					AND (ou2.OrgNode.IsDescendantOf (CurrentUser.OrgNode) = 1)
		   )
				);
GO