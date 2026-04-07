SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SJob].[tvf_EngineeringOverdueActivities] 
(
    @UserId INT
)
RETURNS TABLE
        --WITH SCHEMABINDING
AS
RETURN 
WITH StatusDefs AS
    (
        SELECT
            CancelledGuid = CONVERT(uniqueidentifier, '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64'),
            CompletedGuid = CONVERT(uniqueidentifier, '20D22623-283B-4088-9CEB-D944AC3E6516')
    )
SELECT		
		j.ID,
		j.Number,
		j.RowStatus,
		j.RowVersion,
		j.Guid,
		actt.Name AS Activity,
		CONVERT(DATE,root_hobt.EndDate) AS DueDate,
		actStatus.Name AS Status,
		i.FullName,
		org.Name AS OrgUnit,
		jt.Name AS JobType
FROM    SJob.Activities					AS root_hobt
JOIN	SJob.ActivityTypes				AS actt ON (actt.ID = root_hobt.ActivityTypeID)
JOIN	SJob.ActivityStatus				AS actStatus ON (actStatus.ID = root_hobt.ActivityStatusID)
JOIN	SJob.Jobs						AS j ON (j.ID = root_hobt.JobID)
JOIN	SCore.Identities				AS i ON (i.ID = j.SurveyorID)
JOIN    SCore.OrganisationalUnits		AS org ON (org.ID = j.OrganisationalUnitID)
JOIN	SJob.JobTypes					AS jt ON (jt.ID = j.JobTypeID)
CROSS JOIN StatusDefs   AS sd
-- Latest workflow status for this job (rowstatus safe)
OUTER APPLY
(
    SELECT TOP (1)
        wfs.Guid           AS LatestWorkflowStatusGuid,
        wfs.IsActiveStatus AS LatestIsActiveStatus
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus       AS wfs ON (wfs.ID = dot.StatusID)
    WHERE (dot.RowStatus NOT IN (0,254))
        AND (wfs.RowStatus NOT IN (0,254))
        AND (dot.DataObjectGuid = j.Guid)
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
) AS wf
WHERE			
			(root_hobt.RowStatus NOT IN (0, 254))
		AND (root_hobt.EndDate < GETDATE())
		AND (actStatus.Name NOT IN (N'Complete', N'Cancelled'))
		AND
        (
            CASE
                WHEN wf.LatestWorkflowStatusGuid IS NULL
                    THEN CASE WHEN (ISNULL(j.IsComplete, 0) = 0) AND (j.JobCompleted IS NULL) THEN 1 ELSE 0 END
                ELSE
                    CASE
                        WHEN wf.LatestWorkflowStatusGuid = sd.CompletedGuid THEN 0
                        ELSE 1
                    END
            END
        ) = 1
		AND
        (
            CASE
                WHEN wf.LatestWorkflowStatusGuid IS NULL
                    THEN CASE WHEN (ISNULL(j.IsComplete, 0) = 0) AND (j.JobCompleted IS NULL)  THEN 1 ELSE 0 END
                ELSE
                    CASE
                        WHEN (wf.LatestWorkflowStatusGuid = sd.CompletedGuid) OR (wf.LatestWorkflowStatusGuid = sd.CancelledGuid) THEN 0
                        ELSE 1
                    END
            END
        ) = 1
		AND	(EXISTS
		(
			SELECT	1
			FROM	SCore.ObjectSecurityForUser_CanRead (root_hobt.guid, @UserId) oscr
		)
)
GO