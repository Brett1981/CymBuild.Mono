SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_TeamsNoAcceptanceDocReceived]
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
        j.JobDescription                        AS Description,
        client.Name + N' / ' + agent.Name       AS ClientAgent,
        asset.FormattedAddressComma             AS Asset,
        j.ExternalReference                     AS ExternalReference,
        jt.Name                                 AS JobTypeName,
        j.CreatedOn                             AS CreatedOn,
        j.AppFormReceived,
        i.FullName                              AS Consultant
    FROM SJob.Jobs              AS j
    JOIN SJob.JobStatus         AS js     ON (js.ID = j.ID)
    JOIN SJob.JobTypes          AS jt     ON (j.JobTypeID = jt.ID)
    JOIN SCrm.Accounts          AS client ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts          AS agent  ON (agent.ID = j.AgentAccountID)
    JOIN SJob.Assets            AS asset  ON (asset.ID = j.UprnID)
    JOIN SCore.Identities       AS i      ON (j.SurveyorID = i.ID)

    -- Latest workflow status (rowstatus safe)
    OUTER APPLY
    (
        SELECT TOP (1)
            wfs.Guid            AS LatestStatusGuid,
            wfs.IsActiveStatus  AS LatestIsActiveStatus
        FROM SCore.DataObjectTransition AS dot
        JOIN SCore.WorkflowStatus       AS wfs ON (wfs.ID = dot.StatusID)
        WHERE (dot.RowStatus NOT IN (0,254))
          AND (wfs.RowStatus NOT IN (0,254))
          AND (dot.DataObjectGuid = j.Guid)
        ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
    ) AS wf

    -- Current user's OU node
    CROSS APPLY
    (
        SELECT ou1.OrgNode
        FROM SCore.OrganisationalUnits AS ou1
        JOIN SCore.Identities          AS i1 ON (i1.OriganisationalUnitId = ou1.ID)
        WHERE (i1.ID = @UserId)
    ) AS CurrentUser

    CROSS JOIN StatusDefs sd

    WHERE
        (j.RowStatus NOT IN (0,254))
        AND (j.AppFormReceived = 0)

        -- Must be readable
        AND EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
        )

        -- Must be in the user's OU subtree
        AND EXISTS
        (
            SELECT 1
            FROM SCore.OrganisationalUnits AS ou2
            WHERE (ou2.ID = i.OriganisationalUnitId)
              AND (ou2.OrgNode.IsDescendantOf(CurrentUser.OrgNode) = 1)
        )

        /* --------------------------------------------------------------------
           GLOBAL ACTIVE RULE (latest workflow wins):
           - If workflow exists => must have IsActiveStatus = 1
           - Else => must have legacy IsActive = 1
        -------------------------------------------------------------------- */
        AND
        (
            CASE
                WHEN wf.LatestStatusGuid IS NULL
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
                WHEN wf.LatestStatusGuid IS NULL
                    THEN CASE WHEN ISNULL(j.IsCancelled, 0) = 0 THEN 1 ELSE 0 END
                ELSE
                    CASE
                        WHEN wf.LatestStatusGuid = sd.CancelledGuid THEN 0
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
                WHEN wf.LatestStatusGuid IS NULL
                    THEN CASE WHEN (ISNULL(j.IsComplete, 0) = 0) AND (j.JobCompleted IS NULL) THEN 1 ELSE 0 END
                ELSE
                    CASE
                        WHEN wf.LatestStatusGuid = sd.CompletedGuid THEN 0
                        ELSE 1
                    END
            END
        ) = 1
);
GO