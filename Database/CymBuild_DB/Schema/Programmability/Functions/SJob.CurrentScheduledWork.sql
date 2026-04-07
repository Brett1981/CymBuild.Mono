SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[CurrentScheduledWork]
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
        j.Guid,
        a.RowVersion,
        a.RowStatus,
        j.Number AS JobNumber,
        client.Name AS ClientName,
        prop.FormattedAddressComma AS PropertyAddress,
        a.Date AS StartDateTime,
        a.EndDate AS EndDateTime,
        a.Title AS ActivityTitle,
        aty.Name AS ActivityType,
        ast.Name AS ActivityStatus,
        i.FullName AS SurveyorName,
        ast.SortOrder AS SortPriority
    FROM SJob.Activities        AS a
    JOIN SJob.ActivityStatus    AS ast ON (ast.ID = a.ActivityStatusID)
    JOIN SJob.ActivityTypes     AS aty ON (aty.ID = a.ActivityTypeID)
    JOIN SJob.Jobs              AS j   ON (j.ID = a.JobID)
    JOIN SJob.Assets            AS prop ON (prop.ID = j.UprnID)
    JOIN SCrm.Accounts          AS client ON (client.ID = j.ClientAccountID)
    JOIN SCore.Identities       AS i   ON (i.ID = a.SurveyorID)
    CROSS JOIN StatusDefs       AS sd

    -- Latest workflow status for this JOB (rowstatus safe)
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
        (aty.IsScheduleItem = 1)
        AND (a.SurveyorID = @UserId)
        AND (a.Date BETWEEN DATEADD(DAY, -7, GETUTCDATE()) AND DATEADD(DAY, +7, GETUTCDATE()))
        AND (a.RowStatus NOT IN (0,254))
        AND (j.RowStatus NOT IN (0,254))

        -- Security (job-level)
        AND EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
        )

        /* --------------------------------------------------------------------
           GLOBAL ACTIVE RULE (latest workflow wins):
           - If workflow exists => must have LatestIsActiveStatus = 1
           - Else => must have legacy IsActive = 1
           This also implements: Latest workflow IsActiveStatus = 0 => exclude.
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
           NOT CANCELLED (latest workflow wins)
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
           NOT COMPLETE (latest workflow wins)
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