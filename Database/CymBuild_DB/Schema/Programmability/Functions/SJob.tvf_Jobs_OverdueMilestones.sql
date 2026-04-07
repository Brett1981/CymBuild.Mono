SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_OverdueMilestones]
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
        j.RowVersion,
        j.Guid,
        j.Number,
        j.JobDescription,
        j.JobTypeID,
        jt.Name AS JobTypeName,
        i.Guid AS SurveyorGuid,
        i.FullName AS SurveyorName,
        prop.FormattedAddressComma,
        client.Name + N' / ' + agent.Name AS ClientAgent,
        js.IsSubjectToNDA,
        j.IsComplete,
        js.JobStatus,
        org.Name AS OrgUnit
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus             AS js    ON (js.ID = j.ID)
    JOIN SJob.JobTypes              AS jt    ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities           AS i     ON (j.SurveyorID = i.ID)
    JOIN SJob.Assets                AS prop  ON (prop.ID = j.UprnID)
    JOIN SCrm.Accounts              AS client ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts              AS agent  ON (agent.ID = j.AgentAccountID)
    JOIN SCore.OrganisationalUnits  AS org    ON (org.ID = j.OrganisationalUnitID)
    CROSS JOIN StatusDefs           AS sd

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
        AND (j.SurveyorID = @UserId)

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

        /* --------------------------------------------------------------------
           Overdue milestones exist (unchanged intent)
        -------------------------------------------------------------------- */
        AND EXISTS
        (
            SELECT 1
            FROM SJob.Milestones AS m
            WHERE (m.JobID = j.ID)
              AND (m.RowStatus NOT IN (0,254))
              AND (m.IsComplete = 0)
              AND
              (
                  (ISNULL(m.DueDateTimeUTC,       GETUTCDATE()) < GETUTCDATE())
                  OR
                  (ISNULL(m.ScheduledDateTimeUTC, GETUTCDATE()) < GETUTCDATE())
              )
        )
);
GO