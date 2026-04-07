SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_TeamNoFormalAppointment]
	(
		@UserId INT
	)
RETURNS TABLE
           --WITH SCHEMABINDING
AS
RETURN	 SELECT		j.ID,
					j.RowStatus,
					j.RowVersion,
					j.Guid,
					j.Number,
					j.JobDescription,
					j.JobTypeID,
					client.Name AS  Client,
					jt.Name	   AS JobTypeName,
					i.Guid	   AS SurveyorGuid,
					i.FullName AS SurveyorName,
					j.JobStarted AS DueDateTimeUTC,
					js.IsSubjectToNDA,
					client.Name + N' / ' + agent.Name AS  ClientAgent,
					prop.FormattedAddressComma AS Asset,
					j.ExternalReference,
					jobTypes.Name As JobType,
					CONVERT(NVARCHAR(19),j.CreatedOn) AS CreatedOn,
					i.FullName
	   FROM			SJob.Jobs					  AS j
	   JOIN			SJob.JobStatus AS js ON (js.ID = j.ID)
	   JOIN			SJob.JobTypes				  AS jt ON (j.JobTypeID = jt.ID)
	   JOIN			SCore.Identities			  AS i ON (j.SurveyorID = i.ID)
	   JOIN			SCrm.Accounts client ON (client.ID = j.ClientAccountID)
	   JOIN			SCrm.Accounts agent ON (agent.ID = j.AgentAccountID)
	   JOIN			SJob.Assets prop ON (prop.ID = j.UprnID)
	   JOIN			SJob.JobTypes as jobTypes ON (jobTypes.ID = j.JobTypeID)
	   CROSS APPLY
					(
						SELECT	ou1.OrgNode
						FROM	SCore.OrganisationalUnits AS ou1
						JOIN	SCore.Identities		  AS i1 ON (i1.OriganisationalUnitId = ou1.ID)
						WHERE	(i1.ID = @UserId)
					) AS CurrentUser
	   WHERE		(j.RowStatus NOT IN (0, 254))
				AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
				AND (jt.Name IN (N'CDM PD',N'CDM PD (Construction Phase Only)',N'CDM PD (Pre-Construction Phase Only)'))
				AND	(j.IsActive = 1)
				AND 
				(
					(j.IsCompleteForReview	= 0) AND  
					(NOT EXISTS(
						SELECT 1 
						FROM SCore.DataObjectTransition 
						JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
						WHERE 
							DataObjectGuid = j.Guid AND wfs.Guid = '4BFDB215-3E27-4829-BB44-0468C92DAC82' ))
				
				)
				AND (j.ReviewedByUserID	   < 0)
				AND	(j.ClientAppointmentReceived = 0)
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
				AND (EXISTS
		   (
			   SELECT	1
			   FROM		SCore.OrganisationalUnits AS ou2
			   WHERE	(ou2.ID											  = i.OriganisationalUnitId)
					AND (ou2.OrgNode.IsDescendantOf (CurrentUser.OrgNode) = 1)
		   )
					)
GO