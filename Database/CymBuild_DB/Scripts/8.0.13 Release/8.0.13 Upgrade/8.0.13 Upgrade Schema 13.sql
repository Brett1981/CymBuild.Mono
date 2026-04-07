ALTER   FUNCTION [SJob].[tvf_Jobs_CDM_MyProjects]
	(
		@UserID INT
	)
RETURNS TABLE
  --WITH SCHEMABINDING
AS
RETURN SELECT	
		j.ID																AS ID,
		j.Guid																AS Guid,
		j.RowStatus															AS RowStatus,

																			--[PROJECT]
		ProjectRef.ProjectRef												AS projectRef,						
		client.Name + N' / ' + agent.Name 									AS clientAgent,						
		p.Name + N' / ' + p.FormattedAddressComma							AS propertyName ,					
		CDMRole.jobRole														AS CDMRole,							
		jobstatus.JobStatus													AS jobStatus,						

																			--[FINANCE]
		TotalAgreedFee.Agreed												AS totalAgreed,
		Remaining.Remaining													AS totalRemaining,

																			--[AGREED DELIVERABLES]
		preconmeetings.QuotedMeetings										AS preconMeetings,
		conmeetings.QuotedMeetings											AS conMeetings,
		compliancevisits.compliancevisits									AS complianceVisit,
		HSFile.HSFile														AS hsFile,

																			--[REMAINING DELIVERABLES]
		remainingprecon.remainingPreCon										AS preconMeetingsRemaining,
		remainingconmeetings.reaminingCon									AS conMeetingsRemaining,
		remainingCompVisits.remainingCompVisits								AS compVisitsRemaining,
		HSIssued.HSIssued													AS HSIssued,

																			--[NO HEADER] => [ Client Duties Issued + CDM Strategy Issued]
		clientDutiesIssued.CDIssued											AS clientDutiesIssued,
		CDMStrategyIssued.CDMStratIssued									AS CDMStrategyIssued,

																			--[PCI]
		PCIInspectionCompleted.PCICompleted									AS PCIInspectionCompleted,
		PCIDateCompleted.PCIDate											AS PCIDate,
		--TODO:: PCI VERSION

																			--[RISK]
		DRRLastIssued.DRRLastIssued											AS DRRLastIssued,

																			--[F10]
		F10Applicable.F10Applicable											AS F10Applicable,
		F10IssuedDate.F10Issued												AS F10IssuedDate,
		F10StartDate.F10StartDate											AS F10Start,
		F10WeekDuration.F10WeekDuration										AS F10WeekDuration,
		F10ExpiryDate.F10ExpiryDate											AS F10ExpiryDate,

																			--[CPP]
		CPPDateReceived.CPPDateReceived										AS CPPDateReceived,
		CPPReviewed.CPPReviewed												AS CPPReviewed,			


																			--[PROGRAMME]


																			--[H&S File]
		HSFReviewedDate.HSFReviewedDate										AS HSFReviewed,
		HSFCompletedDate.HSFCompleted										AS HSFCompleted


FROM		SJob.Jobs AS j
JOIN		SJob.JobStatus	AS js ON (js.ID = j.ID)
JOIN		SJob.Properties AS p ON (p.ID = j.UprnID)
JOIN		SJob.JobTypes	AS t ON (t.ID = j.JobTypeID)
JOIN		SCrm.Accounts	AS client ON (client.ID = j.ClientAccountID)
JOIN		SCrm.Accounts	AS agent ON (agent.ID = j.AgentAccountID)
JOIN		SJob.JobStatus  AS jobstatus ON (j.ID = jobstatus.ID)


	OUTER APPLY
	(
		SELECT CASE
			WHEN EXISTS
			(
				SELECT 1
				FROM SSop.Projects AS p
				WHERE p.ID = j.ProjectId AND p.ExternalReference = ''
			)
			THEN CAST(j.ProjectId AS NVARCHAR(15))
			ELSE CAST(j.ProjectId AS NVARCHAR(15)) + N' - ' + CAST(j.ExternalReference AS NVARCHAR(50))
			END AS ProjectRef
	) AS ProjectRef																			--Project Reference


	OUTER APPLY 
	(
		SELECT jt.Name AS jobRole
		FROM SJob.JobTypes as jt
		WHERE jt.ID = j.JobTypeID
	) AS CDMRole


		--[FINANCE]
	OUTER APPLY
		(
			SELECT jobfee.Agreed
			FROM SJob.Job_FeeDrawdown AS jobfee
			WHERE jobfee.StageId = -2 AND jobfee.JobId = j.ID
		) AS TotalAgreedFee																		--Total Agreed Fee
	OUTER APPLY
		(
			SELECT jobfee.Remaining
			FROM SJob.Job_FeeDrawdown AS jobfee
			WHERE jobfee.StageId = -2 AND jobfee.JobId = j.ID
		) AS Remaining																		--Remaining Fee
					
					
		--[AGREED DELIVERABLES]
		OUTER APPLY
		(
			SELECT jobfee.QuotedMeetings
			FROM SJob.Job_FeeDrawdown AS jobfee
			WHERE jobfee.StageId = 10 AND jobfee.JobId = j.ID
		) AS preconmeetings																	--Pre-Con. Meetings
		
		OUTER APPLY
		(
			SELECT jobfee.QuotedMeetings
			FROM SJob.Job_FeeDrawdown AS jobfee
			WHERE jobfee.StageId = 11 AND jobfee.JobId = j.ID
		) AS conmeetings																	--Con. Meetings
		
		OUTER APPLY
		(
			SELECT COUNT(act.ID) AS compliancevisits
			FROM SJob.Activities AS act 
			WHERE act.ActivityTypeID = 23 AND act.JobID = j.ID 
		) AS compliancevisits																--Compliance Visits
		
		OUTER APPLY
		(
			SELECT CASE
				WHEN EXISTS
				(
					SELECT 1 FROM Sjob.Milestones AS m
					WHERE m.MilestoneTypeID = 8 AND m.JobID = j.ID
				) 
			THEN N'Yes'
			ELSE N'No'
			END AS HSFile
		) AS HSFile																			--H&S File (Yes/No)
		

		--[REMAINING DELIVERABLES]
		OUTER APPLY
		(
			SELECT (jobfee.QuotedMeetings - jobfee.CompletedMeetings) AS remainingPreCon
			FROM SJob.Job_FeeDrawdown AS jobfee
			WHERE jobfee.StageId = 10 AND jobfee.JobId = j.ID
		) AS remainingprecon																	--Pre-con Mtgs remaining.

		OUTER APPLY
		(
			
			SELECT (jobfee.QuotedMeetings - jobfee.CompletedMeetings) as reaminingCon
			FROM SJob.Job_FeeDrawdown AS jobfee
			WHERE jobfee.StageId = 11 AND jobfee.JobId = j.ID
	
		) AS remainingconmeetings																--Con Mtgs remaining.

		OUTER APPLY
		(
			SELECT 
				(COUNT(Act.ID) - 
					(SELECT COUNT(Act.ID) -- use primary key
					 FROM SJob.Activities AS Act 
					 WHERE Act.ActivityTypeID = 23 
					   AND Act.JobID = j.ID 
					   AND Act.ActivityStatusID = 3)
				) AS remainingCompVisits
			FROM SJob.Activities AS Act 
			WHERE Act.ActivityTypeID = 23 
			  AND Act.JobID = j.ID

		) AS remainingCompVisits																--Compliance visits

		OUTER APPLY 
		(
			SELECT CASE
			WHEN EXISTS
			(
				SELECT 1
				FROM SJob.Milestones AS bool
				WHERE JobID = j.ID AND MilestoneTypeID = 8 AND IsComplete = 1
			)
			THEN N'Yes'
			ELSE N'No'
			END AS HSIssued																		--H&S Issued

		) AS HSIssued

		OUTER APPLY 
		(
			SELECT CASE 
			WHEN EXISTS
			(
				SELECT 1 
				FROM Sjob.Milestones AS m
				WHERE m.MilestoneTypeID = 2 AND m.IsComplete = 1  AND m.JobID = j.ID
			)
			THEN N'Yes'
			ELSE N'No'
			END AS CDIssued
		) AS clientDutiesIssued																	--Client Duties Issued

		OUTER APPLY 
		(
			SELECT CASE 
			WHEN EXISTS
			(
				SELECT 1 
				FROM Sjob.Milestones AS m
				WHERE m.MilestoneTypeID = 1 AND m.IsComplete = 1  AND m.JobID = j.ID
			)
			THEN N'Yes'
			ELSE N'No'
			END AS CDMStratIssued
		) AS CDMStrategyIssued																	--CDM Strategy Issued

		OUTER APPLY
		(
			SELECT CASE 
			WHEN EXISTS
			(
				SELECT 1 
				FROM Sjob.Milestones AS m
				WHERE m.MilestoneTypeID = 11 AND m.IsComplete = 1  AND m.JobID = j.ID
			)
			THEN N'Yes'
			ELSE N'No'
			END AS PCICompleted
		) AS PCIInspectionCompleted																		-- PCI Inspection Completed

		OUTER APPLY
		(
			SELECT CASE 
			WHEN EXISTS
			(
				SELECT 1
				FROM Sjob.Milestones AS m
				WHERE m.MilestoneTypeID = 11 AND m.IsComplete = 1  AND m.JobID = j.ID
			)
			THEN (SELECT CAST(m.CompletedDateTimeUTC AS DATE) FROM Sjob.Milestones AS m WHERE m.MilestoneTypeID = 11 AND m.JobID = j.ID)
			ELSE NULL
			END AS PCIDate
		) AS PCIDateCompleted																			-- PCI/PDI Date


		--OUTER APPLY 
		--(
		
		--) AS PCIVersion																				--PCI Version ============ TODOD!!!! ============

		OUTER APPLY 
		(
			SELECT CASE
			WHEN EXISTS
			(
				SELECT 1 
				FROM SJob.Activities AS act
				WHERE act.JobID = j.ID AND act.ActivityTypeID = 26 AND act.ActivityStatusID = 3
			)
			THEN (SELECT CAST(act.EndDate AS DATE) FROM Sjob.Activities AS act WHERE act.JobID = j.ID AND act.ActivityTypeID = 26 AND act.ActivityStatusID = 3) 
			ELSE NULL 
			END AS DRRLastIssued
		) AS DRRLastIssued																				--DRR Last Issued


		OUTER APPLY
		(
			SELECT CASE 
				WHEN EXISTS
				(
					SELECT 1 FROM SJob.Milestones WHERE JobID = j.ID AND MilestoneTypeID = 7
				)
				THEN N'Yes'
				ELSE N'No'
			END AS F10Applicable
		) AS F10Applicable																				--F10 Applicable

		OUTER APPLY
		(
			SELECT CASE
			WHEN EXISTS
				(
					SELECT 1 FROM SJob.Milestones WHERE JobID = j.ID AND MilestoneTypeID = 7
				)
				THEN 
				(
					SELECT CAST(CAST(m.CompletedDateTimeUTC AS DATE) AS VARCHAR)
					FROM SJob.Milestones AS m
					WHERE m.MilestoneTypeID = 7 AND JobID = j.ID
				)
				ELSE N'#808080' -- return grey hex 
			END AS F10Issued
		) AS F10IssuedDate																				--F10 Issued Date

		OUTER APPLY 
		(
			SELECT CASE
				WHEN EXISTS
					(
						SELECT 1 FROM SJob.Milestones WHERE JobID = j.ID AND MilestoneTypeID = 7
					)
					THEN 
					(
						SELECT CAST(CAST(m.StartDateTimeUTC AS DATE) AS VARCHAR)
						FROM SJob.Milestones AS m
						WHERE m.MilestoneTypeID = 7 AND JobID = j.ID
					)
					ELSE N'#808080'
			END AS F10StartDate
		) AS F10StartDate																			--F10 Start Date

		OUTER APPLY 
		(
			SELECT CASE
				WHEN EXISTS
					(
						SELECT 1 FROM SJob.Milestones WHERE JobID = j.ID AND MilestoneTypeID = 7
					)
					THEN 
					(
						SELECT CAST(DATEDIFF(WEEK, CAST(m.StartDateTimeUTC AS DATE), CAST(m.DueDateTimeUTC AS DATE)) AS VARCHAR) 
						FROM SJob.Milestones AS m
						WHERE m.MilestoneTypeID = 7 AND JobID = j.ID
					)
					ELSE N'#808080'
				END AS F10WeekDuration
		) AS F10WeekDuration																		--F10 Duration (wks)

		OUTER APPLY 
		(
			SELECT CASE
				WHEN EXISTS
					(
						SELECT 1 FROM SJob.Milestones WHERE JobID = j.ID AND MilestoneTypeID = 7
					)
					THEN 
					(
						SELECT CAST(CAST(m.SubmissionExpiryDate AS DATE) AS VARCHAR)
						FROM SJob.Milestones AS m
						WHERE m.MilestoneTypeID = 7 AND JobID = j.ID
					)
					ELSE N'#808080'
			END AS F10ExpiryDate
		) AS F10ExpiryDate																			--F10 Expiry Date

		OUTER APPLY
		(
			SELECT CASE
					WHEN EXISTS
						(
							SELECT 1 FROM SJob.Milestones WHERE JobID = j.ID AND MilestoneTypeID = 19
						)
						THEN 
						(
							SELECT CAST(m.CompletedDateTimeUTC AS DATE)
							FROM SJob.Milestones AS m
							WHERE m.MilestoneTypeID = 19 AND JobID = j.ID
						)
						ELSE NULL
				END AS CPPDateReceived
		) AS CPPDateReceived																		-- CPP Date / Received	

		OUTER APPLY
		(
			SELECT CASE
				WHEN EXISTS
					(
						SELECT 1 FROM SJob.Milestones WHERE JobID = j.ID AND MilestoneTypeID = 17
					)
					THEN 
					(
						SELECT CAST(m.CompletedDateTimeUTC AS DATE)
						FROM SJob.Milestones AS m
						WHERE m.MilestoneTypeID = 17 AND JobID = j.ID
					)
					ELSE NULL
			END AS CPPReviewed
		) AS CPPReviewed																			-- CPP Reviewed 

		--OUTER APPLY
		--(
		
		--) AS ConstructionStartDate																-- Construction Start Date =======> [TODO]

		--OUTER APPLY
		--(
		
		--) AS ConstructionCompletionDate															-- Construction Completion Date =======> [TODO]

		--OUTER APPLY
		--(
		
		--) AS ConstuctionDuration																	-- (Construction) Duration (wks) =======> [TODO]

		OUTER APPLY
		(
			SELECT CAST(m.ReviewedDateTimeUTC AS DATE) AS HSFReviewedDate
			FROM SJob.Milestones as m 
			WHERE m.MilestoneTypeID = 8 AND  m.JobID = j.ID
		) AS HSFReviewedDate																		--HSF Reviewed

		OUTER APPLY
		(
			SELECT CAST(m.CompletedDateTimeUTC AS DATE) AS HSFCompleted
			FROM SJob.Milestones as m 
			WHERE m.MilestoneTypeID = 8 AND  m.JobID = j.ID
		) AS HSFCompletedDate																		--HSF Completed
		
		
WHERE (j.IsActive	  = 1)
		AND (EXISTS
		(
			SELECT	1
			FROM		SCore.ObjectSecurityForUser_CanRead (	j.Guid,
															@UserID
														) AS oscr
		)
			)
		AND (j.RowStatus NOT IN (0, 254))
		AND (j.SurveyorID = @UserID)
		AND (j.ID		  > 0);
GO


