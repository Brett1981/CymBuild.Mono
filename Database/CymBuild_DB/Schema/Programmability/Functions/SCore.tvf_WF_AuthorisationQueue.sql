SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =============================================================================
   SCore.tvf_WF_AuthorisationQueue
   ---------------------------------------------------------------------------
   - Expose LatestStatusId and LatestOldStatusId in the FINAL SELECT so callers
     (EF/API) can read them directly.
   - Add these columns to the FINAL GROUP BY.
============================================================================= */

CREATE FUNCTION [SCore].[tvf_WF_AuthorisationQueue]
(
    @UserId INT = NULL,
    @EntityTypeId INT = -1
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
(
    WITH LatestTransition AS
    (
        SELECT
            dot.DataObjectGuid,
            dot.Guid        AS LatestTransitionGuid,
            dot.DateTimeUTC AS LatestTransitionUtc,
            dot.StatusID    AS LatestStatusId,
            dot.OldStatusID AS LatestOldStatusId,
            ROW_NUMBER() OVER
            (
                PARTITION BY dot.DataObjectGuid
                ORDER BY dot.ID DESC
            ) AS rn
        FROM SCore.DataObjectTransition dot
        WHERE dot.RowStatus NOT IN (0,254)
    ),
    Latest AS
    (
        SELECT
            lt.DataObjectGuid,
            lt.LatestTransitionGuid,
            lt.LatestTransitionUtc,
            lt.LatestStatusId,
            lt.LatestOldStatusId
        FROM LatestTransition lt
        WHERE lt.rn = 1
    ),
    Routed AS
    (
        /* Ensure ONE routing row per DataObjectGuid (prevents duplication) */
        SELECT
            rPick.DataObjectGuid,
            rPick.EntityTypeId,
            rPick.OrganisationalUnitId,

            l.LatestTransitionGuid,
            l.LatestTransitionUtc,
            l.LatestStatusId,
            l.LatestOldStatusId
        FROM Latest l
        OUTER APPLY
        (
            SELECT TOP (1)
                r.DataObjectGuid,
                r.EntityTypeId,
                r.OrganisationalUnitId
            FROM SCore.WF_Auth_DataObjectRouting r
            WHERE r.DataObjectGuid = l.DataObjectGuid
              AND r.OrganisationalUnitId IS NOT NULL
              AND r.EntityTypeId IS NOT NULL
              AND (@EntityTypeId = -1 OR r.EntityTypeId = @EntityTypeId)
            ORDER BY r.ResolvedFrom, r.EntityTypeId, r.OrganisationalUnitId
        ) rPick
        WHERE rPick.DataObjectGuid IS NOT NULL
    ),
    StatusMeta AS
    (
        SELECT
            ro.DataObjectGuid,
            ro.EntityTypeId,
            ro.OrganisationalUnitId,

            ro.LatestTransitionGuid,
            ro.LatestTransitionUtc,
            ro.LatestStatusId,
            ro.LatestOldStatusId,

            ws.Guid AS LatestWorkflowStatusGuid,
            ws.Name AS LatestWorkflowStatusName,

            ws.IsActiveStatus   AS LatestIsActiveStatus,
            ws.IsCompleteStatus AS LatestIsCompleteStatus,

            ws.AuthorisationNeeded
        FROM Routed ro
        JOIN SCore.WorkflowStatus ws
            ON ws.ID = ro.LatestStatusId
           AND ws.RowStatus NOT IN (0,254)
        WHERE ISNULL(ws.AuthorisationNeeded, 0) = 1
    ),
    WorkflowResolved AS
    (
        SELECT
            sm.DataObjectGuid,
            sm.EntityTypeId,
            sm.OrganisationalUnitId,

            sm.LatestTransitionGuid,
            sm.LatestTransitionUtc,
            sm.LatestStatusId,
            sm.LatestOldStatusId,

            sm.LatestWorkflowStatusGuid,
            sm.LatestWorkflowStatusName,
            sm.LatestIsActiveStatus,
            sm.LatestIsCompleteStatus,
            sm.AuthorisationNeeded,

            wf.ID AS WorkflowId
        FROM StatusMeta sm
        JOIN SCore.Workflow wf
            ON wf.RowStatus NOT IN (0,254)
           AND ISNULL(wf.Enabled, 1) = 1
           AND wf.EntityTypeID = sm.EntityTypeId
           AND wf.OrganisationalUnitId = sm.OrganisationalUnitId
        JOIN SCore.WorkflowTransition wft
            ON wft.RowStatus NOT IN (0,254)
           AND ISNULL(wft.Enabled, 1) = 1
           AND wft.WorkflowID = wf.ID
           AND wft.ToStatusID = sm.LatestStatusId
    ),
    GroupMap AS
    (
        SELECT
            wr.DataObjectGuid,
            wr.EntityTypeId,
            wr.OrganisationalUnitId,

            wr.LatestTransitionGuid,
            wr.LatestTransitionUtc,
            wr.LatestStatusId,
            wr.LatestOldStatusId,

            wr.LatestWorkflowStatusGuid,
            wr.LatestWorkflowStatusName,
            wr.LatestIsActiveStatus,
            wr.LatestIsCompleteStatus,
            wr.AuthorisationNeeded,

            wr.WorkflowId,

            ng.GroupID,
            ng.CanAction
        FROM WorkflowResolved wr
        JOIN SCore.WorkflowStatusNotificationGroups ng
            ON ng.RowStatus NOT IN (0,254)
           AND ng.WorkflowID = wr.WorkflowId
           AND ng.WorkflowStatusGuid = wr.LatestWorkflowStatusGuid
    ),
    UserScoped AS
    (
        SELECT
            gm.DataObjectGuid,
            gm.EntityTypeId,
            gm.OrganisationalUnitId,
            gm.WorkflowId,

            gm.LatestWorkflowStatusGuid,
            gm.LatestWorkflowStatusName,
            gm.LatestTransitionGuid,
            gm.LatestTransitionUtc,
            gm.LatestStatusId,
            gm.LatestOldStatusId,

            gm.LatestIsActiveStatus,
            gm.LatestIsCompleteStatus,
            gm.AuthorisationNeeded,

            gm.GroupID,
            gm.CanAction,

            ug.IdentityID
        FROM GroupMap gm
        LEFT JOIN SCore.UserGroups ug
            ON ug.RowStatus NOT IN (0,254)
           AND ug.GroupID = gm.GroupID
           AND (@UserId IS NULL OR ug.IdentityID = @UserId)
    )
    SELECT
        @UserId AS UserId,

        us.DataObjectGuid,
        us.EntityTypeId,
        us.OrganisationalUnitId,
        us.WorkflowId,

        us.LatestWorkflowStatusGuid,
        us.LatestWorkflowStatusName,
        us.LatestTransitionGuid,
        us.LatestTransitionUtc,

        /* expose these for EF/API */
        us.LatestStatusId,
        us.LatestOldStatusId,

        us.LatestIsActiveStatus,
        us.LatestIsCompleteStatus,

        TargetGroupIdsCsv =
            STUFF((
                SELECT ',' + CONVERT(NVARCHAR(20), x.GroupID)
                FROM
                (
                    SELECT DISTINCT us2.GroupID
                    FROM UserScoped us2
                    WHERE us2.DataObjectGuid = us.DataObjectGuid
                      AND us2.WorkflowId = us.WorkflowId
                      AND us2.LatestWorkflowStatusGuid = us.LatestWorkflowStatusGuid
                ) x
                ORDER BY x.GroupID
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 1, ''),

        CanActionForUser =
            CASE
                WHEN @UserId IS NULL THEN CAST(0 AS bit)
                WHEN EXISTS
                (
                    SELECT 1
                    FROM UserScoped us3
                    WHERE us3.DataObjectGuid = us.DataObjectGuid
                      AND us3.WorkflowId = us.WorkflowId
                      AND us3.LatestWorkflowStatusGuid = us.LatestWorkflowStatusGuid
                      AND us3.IdentityID = @UserId
                      AND ISNULL(us3.CanAction, 0) = 1
                )
                THEN CAST(1 AS bit)
                ELSE CAST(0 AS bit)
            END
    FROM UserScoped us
    WHERE
        (
            @UserId IS NULL
            OR EXISTS
            (
                SELECT 1
                FROM UserScoped us4
                WHERE us4.DataObjectGuid = us.DataObjectGuid
                  AND us4.WorkflowId = us.WorkflowId
                  AND us4.LatestWorkflowStatusGuid = us.LatestWorkflowStatusGuid
                  AND us4.IdentityID = @UserId
            )
        )
    GROUP BY
        us.DataObjectGuid,
        us.EntityTypeId,
        us.OrganisationalUnitId,
        us.WorkflowId,
        us.LatestWorkflowStatusGuid,
        us.LatestWorkflowStatusName,
        us.LatestTransitionGuid,
        us.LatestTransitionUtc,

        /* must be in GROUP BY because selected */
        us.LatestStatusId,
        us.LatestOldStatusId,

        us.LatestIsActiveStatus,
        us.LatestIsCompleteStatus
);
GO