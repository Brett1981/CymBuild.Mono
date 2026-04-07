SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SJob].[tvf_EngineeringOverdueMilestones] 
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
		j.RowStatus,
		j.RowVersion,
		j.Guid,
		j.Number AS JobNumber,
		mt.Name AS MilestoneName,
		CONVERT(DATE,m.DueDateTimeUTC) AS DueDate,
		i.FullName,
		org.Name AS OrgUnit,
		jt.Name AS JobType
FROM	SJob.Milestones				  AS m
JOIN	SJob.MilestoneTypes			  AS mt ON (mt.ID = m.MilestoneTypeID)
JOIN	SJob.Jobs					  AS j ON (j.ID = m.JobID)
JOIN	SCore.Identities			  AS i ON (i.ID = j.SurveyorID)
JOIN    SCore.OrganisationalUnits	  AS org ON (org.ID = j.OrganisationalUnitID)
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
			(m.RowStatus NOT IN (0, 254))
		AND (m.DueDateTimeUTC < GETDATE())
		AND (m.CompletedDateTimeUTC IS NULL)
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
                    THEN CASE WHEN (ISNULL(j.IsComplete, 0) = 0) AND (j.JobCompleted IS NULL) THEN 1 ELSE 0 END
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
					FROM	SCore.ObjectSecurityForUser_CanRead (m.guid, @UserId) oscr
				)
)
GO