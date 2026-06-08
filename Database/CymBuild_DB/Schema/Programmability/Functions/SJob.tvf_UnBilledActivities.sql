SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_UnBilledActivities] 
(
    @UserId INT
)
RETURNS TABLE
           --WITH SCHEMABINDING
AS
RETURN
/*
	Dashboard: Unbilled Activities

	Purpose:
	Returns all completed billable activities that have not yet been invoiced, providing visibility
	of activities awaiting billing action.

	Business Requirements:
	- Display completed billable activities across all active jobs.
	- Include activities where:
		• No invoice request has been created.
		• An invoice request has been created but the activity has not yet been invoiced.
	- Support the Unbilled Activities dashboard.

	Returned Fields:
	- Job Number
	- Activity
	- Completion Date
	- Consultant
	- Business Unit
	- Job Type
	- Invoice Request Status (Created / Not Created)

	Filtering Rules:
	- Activity status must be Completed.
	- Activity type must be Billable.
	- Job must be active (not cancelled, dormant, completed, dead, or legacy).
	- Activity must not have been invoiced through a transaction.
	- User must have read access to the job.

	Invoice Request Status:
	- 'Created'     : At least one active Invoice Request Item exists for the activity.
	- 'Not Created' : No active Invoice Request Item exists for the activity.

	Used By:
	- Unbilled Activities Dashboard
*/

SELECT 
	root_hobt.ID,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.Title,
	j.Guid,
	I.FullName AS Consultant,
	Org.Name AS BusinessUnit,
	JT.Name AS JobType,
	--Check if there is an invoice request created.
	CASE
		WHEN EXISTS
		(
			SELECT 1
			FROM SFin.InvoiceRequests IR
			JOIN SFin.InvoiceRequestItems IRI
				ON IR.ID = IRI.InvoiceRequestId
			WHERE
					IR.RowStatus NOT IN (0,254)
				AND IRI.RowStatus NOT IN (0,254)
				AND IRI.ActivityId = root_hobt.ID
		)
		THEN N'Created'
		ELSE N'Not Created'
	END AS IsInvoiceReqCreated,
	j.Number,
	Sec.Name AS Sector
FROM SJob.Activities			AS root_hobt
JOIN SJob.Jobs					AS J	ON (J.ID = root_hobt.JobID)
JOIN SCore.Identities			AS I	ON (I.ID = root_hobt.CreatedByUserID)
JOIN SCore.OrganisationalUnits	AS Org  ON (Org.ID = J.OrganisationalUnitID) 
JOIN SJob.JobTypes				AS JT	ON (JT.ID = J.JobTypeID)
JOIN SJob.ActivityTypes			AS ActT	ON (ActT.ID = root_hobt.ActivityTypeID)
JOIN SCore.Sectors				AS Sec	ON (Sec.ID = j.SectorId)
WHERE 
		(root_hobt.ActivityStatusID = 3)
	AND (root_hobt.RowStatus NOT IN (0,254))
	AND J.RowStatus NOT IN (0,254)
	AND (ActT.IsBillable = 1) 
	--Old statuses
	AND J.JobCancelled IS NULL
	AND J.DeadDate IS NULL
	AND J.JobCompleted IS NULL
	AND J.JobDormant IS NULL
	AND J.LegacyID IS NULL

	--[There is no transaction against the activity]
	AND NOT EXISTS
		(
			SELECT 1 
			FROM SFin.TransactionDetails AS T
			WHERE 
					(T.ActivityID = root_hobt.ID)
				AND (T.RowStatus NOT IN (0,254))
				--In case there are multiple requests for one activity.
				AND NOT EXISTS
					(
						SELECT 1  
						FROM SFin.TransactionDetails AS T2
						WHERE 
								(T2.ActivityID = root_hobt.ID)
							AND (T2.ID <> T.ID)
							AND (T2.RowStatus NOT IN (0,254))

					)
		)
	--[Exclude completed jobs]
	AND NOT EXISTS
		(
			SELECT 1 
			FROM SCore.DataObjectTransition Dot
			JOIN SCore.WorkflowStatus AS Wfs ON (Wfs.ID = Dot.StatusID)
			WHERE
					(Dot.RowStatus NOT IN (0,254))
				AND (Dot.DataObjectGuid = J.Guid)
				AND (Wfs.Guid = '20D22623-283B-4088-9CEB-D944AC3E6516')
				AND NOT EXISTS
					(
						SELECT 1 
						FROM SCore.DataObjectTransition AS Dot2
						WHERE 
							(Dot2.RowStatus NOT IN (0,254))
						AND (Dot2.DataObjectGuid = J.Guid)
						AND (Dot2.ID > Dot.ID)
					)

		)
	AND EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
    )
	--ORDER BY 
	--		J.Number, 
	--		root_hobt.ID DESC
	
GO