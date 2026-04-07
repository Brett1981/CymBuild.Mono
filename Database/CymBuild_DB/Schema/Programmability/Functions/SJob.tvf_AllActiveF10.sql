SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_AllActiveF10]
(
    @UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
(
    WITH StatusDefs AS
    (
        SELECT
            CancelledGuid = CONVERT(uniqueidentifier, '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64'),
            CompletedGuid = CONVERT(uniqueidentifier, '20D22623-283B-4088-9CEB-D944AC3E6516')
    )
    SELECT
        j.ID,
        j.RowStatus,
        j.Guid,
        j.RowVersion,
        i.FullName,
        j.Number,
        j.JobDescription,
        p.FormattedAddressComma,
        m.StartDateTimeUTC,
        ISNULL(m.DueDateTimeUTC, m.ScheduledDateTimeUTC) AS NextAction,
        m.Reference,
        js.JobStatus
    FROM SJob.Jobs          AS j
    JOIN SJob.JobStatus     AS js ON (js.ID = j.ID)
    JOIN SCore.Identities   AS i  ON (i.ID = j.SurveyorID)
    JOIN SJob.Milestones    AS m  ON (m.JobID = j.ID)
    JOIN SJob.MilestoneTypes AS mt ON (mt.ID = m.MilestoneTypeID)
    JOIN SJob.Assets        AS p  ON (p.ID = j.UprnID)
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
        (j.RowStatus NOT IN (0,254))
        AND (m.RowStatus NOT IN (0,254))
        AND (mt.Name = N'F10')
        AND (m.StartDateTimeUTC IS NOT NULL)

        AND EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
        )

        /* --------------------------------------------------------------------
           GLOBAL ACTIVE RULE (latest workflow wins):
           - If workflow exists => must have IsActiveStatus = 1
           - Else => must have legacy IsActive = 1
        -------------------------------------------------------------------- */
        AND
        (
            CASE
                WHEN wf.LatestWorkflowStatusGuid IS NULL
                    THEN ISNULL(j.IsActive, 0)
                ELSE ISNULL(wf.LatestIsActiveStatus, 0)
            END
        ) = 1

        /* --------------------------------------------------------------------
           NOT CANCELLED (latest workflow wins):
           - If workflow exists -> latest status must not be Cancelled
           - Else -> legacy IsCancelled must be 0
        -------------------------------------------------------------------- */
        AND
        (
            CASE
                WHEN wf.LatestWorkflowStatusGuid IS NULL
                    THEN CASE WHEN ISNULL(j.IsCancelled, 0) = 0 THEN 1 ELSE 0 END
                ELSE
                    CASE
                        WHEN wf.LatestWorkflowStatusGuid = sd.CancelledGuid THEN 0
                        ELSE 1
                    END
            END
        ) = 1

        /* --------------------------------------------------------------------
           NOT COMPLETE (latest workflow wins):
           - If workflow exists -> latest status must not be Completed
           - Else -> legacy IsComplete=0 AND JobCompleted IS NULL
        -------------------------------------------------------------------- */
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
);
GO