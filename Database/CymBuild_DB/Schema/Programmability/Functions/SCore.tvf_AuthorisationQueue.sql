SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =============================================================================
   Task 3 — Canonical Authorisation Queue
   Function: SCore.tvf_AuthorisationQueue(@UserId)

   NOTE (Grid compatibility):
   - Adds standard columns: ID, RowStatus, RowVersion, Guid
   - ID = TransitionId (int)
   - RowStatus = 1 (tinyint)
   - RowVersion = 0x0000000000000000 cast as binary(8) (placeholder)
   - Guid = DataObjectGuid (the record being authorised)
============================================================================= */
CREATE FUNCTION [SCore].[tvf_AuthorisationQueue]
(
    @UserId INT
)
RETURNS TABLE
--WITH SCHEMABINDING
AS
RETURN
(
    WITH UserActionGroups AS
    (
        SELECT DISTINCT
            ug.GroupID
        FROM SCore.UserGroups ug
        JOIN SCore.Identities i
            ON i.ID = ug.IdentityID
           AND i.RowStatus NOT IN (0,254)
           AND i.IsActive = 1
        WHERE ug.RowStatus NOT IN (0,254)
          AND ug.IdentityID = @UserId
    ),
    RoutedObjects AS
    (
        SELECT
            r.DataObjectGuid,
            r.EntityTypeId,
            r.OrganisationalUnitId,
            r.ResolvedFrom
        FROM SCore.WF_Auth_DataObjectRouting r
        WHERE r.OrganisationalUnitId IS NOT NULL
          AND r.EntityTypeId IS NOT NULL
    ),
    LatestTransition AS
    (
        SELECT
            ro.DataObjectGuid,
            ro.EntityTypeId,
            ro.OrganisationalUnitId,
            ro.ResolvedFrom,

            dot.ID              AS TransitionId,
            dot.Guid            AS TransitionGuid,
            dot.DateTimeUTC     AS TransitionDateTimeUtc,
            dot.StatusID        AS StatusId,
            dot.OldStatusID     AS OldStatusId,
            dot.Comment         AS TransitionComment,
            dot.CreatedByUserId AS ActorIdentityId,
            ISNULL(dot.SurveyorUserId, -1) AS SurveyorIdentityId
        FROM RoutedObjects ro
        OUTER APPLY
        (
            SELECT TOP (1)
                d.ID,
                d.Guid,
                d.StatusID,
                d.OldStatusID,
                d.Comment,
                d.DateTimeUTC,
                d.CreatedByUserId,
                d.SurveyorUserId
            FROM SCore.DataObjectTransition d
            WHERE d.RowStatus NOT IN (0,254)
              AND d.DataObjectGuid = ro.DataObjectGuid
            ORDER BY d.ID DESC
        ) dot
        WHERE dot.ID IS NOT NULL
    ),
    StatusMeta AS
    (
        SELECT
            lt.DataObjectGuid,
            lt.EntityTypeId,
            lt.OrganisationalUnitId,
            lt.ResolvedFrom,

            lt.TransitionId,
            lt.TransitionGuid,
            lt.TransitionDateTimeUtc,
            lt.StatusId,
            lt.OldStatusId,
            lt.TransitionComment,
            lt.ActorIdentityId,
            lt.SurveyorIdentityId,

            ws.Guid AS WorkflowStatusGuid,
            ws.Name AS WorkflowStatusName,
            ISNULL(ws.IsActiveStatus, 0) AS LatestIsActiveStatus,
            ISNULL(ws.AuthorisationNeeded, 0) AS AuthorisationNeeded
        FROM LatestTransition lt
        JOIN SCore.WorkflowStatus ws
            ON ws.ID = lt.StatusId
           AND ws.RowStatus NOT IN (0,254)
    ),
    WorkflowResolved AS
    (
        SELECT
            sm.DataObjectGuid,
            sm.EntityTypeId,
            sm.OrganisationalUnitId,
            sm.ResolvedFrom,

            sm.TransitionId,
            sm.TransitionGuid,
            sm.TransitionDateTimeUtc,
            sm.StatusId,
            sm.OldStatusId,
            sm.TransitionComment,
            sm.ActorIdentityId,
            sm.SurveyorIdentityId,

            sm.WorkflowStatusGuid,
            sm.WorkflowStatusName,
            sm.LatestIsActiveStatus,
            sm.AuthorisationNeeded,

            wfResolved.WorkflowId
        FROM StatusMeta sm
        OUTER APPLY
        (
            SELECT TOP (1)
                wf.ID AS WorkflowId
            FROM SCore.Workflow wf
            JOIN SCore.WorkflowTransition wft
                ON wft.WorkflowID = wf.ID
               AND wft.RowStatus NOT IN (0,254)
               AND ISNULL(wft.Enabled, 1) = 1
            WHERE wf.RowStatus NOT IN (0,254)
              AND ISNULL(wf.Enabled, 1) = 1
              AND wf.EntityTypeID = sm.EntityTypeId
              AND wf.OrganisationalUnitId = sm.OrganisationalUnitId
              AND wft.ToStatusID = sm.StatusId
            ORDER BY wf.ID DESC
        ) wfResolved
        WHERE wfResolved.WorkflowId IS NOT NULL
    ),
    MappedGroups AS
    (
        SELECT
            wr.DataObjectGuid,
            wr.EntityTypeId,
            wr.OrganisationalUnitId,
            wr.ResolvedFrom,

            wr.WorkflowId,

            wr.TransitionId,
            wr.TransitionGuid,
            wr.TransitionDateTimeUtc,
            wr.StatusId,
            wr.OldStatusId,
            wr.TransitionComment,
            wr.ActorIdentityId,
            wr.SurveyorIdentityId,

            wr.WorkflowStatusGuid,
            wr.WorkflowStatusName,
            wr.LatestIsActiveStatus,
            wr.AuthorisationNeeded,

            ng.GroupID,
            ng.CanAction
        FROM WorkflowResolved wr
        JOIN SCore.WorkflowStatusNotificationGroups ng
            ON ng.RowStatus NOT IN (0,254)
           AND ng.WorkflowID = wr.WorkflowId
           AND ng.WorkflowStatusGuid = wr.WorkflowStatusGuid
    ),
    Eligible AS
    (
        SELECT DISTINCT
            mg.DataObjectGuid,
            mg.EntityTypeId,
            mg.OrganisationalUnitId,
            mg.ResolvedFrom,

            mg.WorkflowId,

            mg.TransitionId,
            mg.TransitionGuid,
            mg.TransitionDateTimeUtc,
            mg.StatusId,
            mg.WorkflowStatusGuid,
            mg.WorkflowStatusName,
            mg.LatestIsActiveStatus,
            mg.AuthorisationNeeded,

            mg.TransitionComment,
            mg.ActorIdentityId,
            mg.SurveyorIdentityId
        FROM MappedGroups mg
        WHERE mg.AuthorisationNeeded = 1
          AND mg.LatestIsActiveStatus = 1
          AND EXISTS
          (
              SELECT 1
              FROM MappedGroups mg2
              JOIN UserActionGroups uag
                ON uag.GroupID = mg2.GroupID
              WHERE mg2.DataObjectGuid = mg.DataObjectGuid
                AND mg2.WorkflowId = mg.WorkflowId
                AND mg2.WorkflowStatusGuid = mg.WorkflowStatusGuid
                AND mg2.CanAction = 1
          )
    )
    SELECT
        /* ------------------------------------------------------------
           Standard columns required by DynamicGrid conventions
        ------------------------------------------------------------ */
        ID        = CONVERT(int, e.TransitionId),
        RowStatus = CONVERT(tinyint, 1),
        RowVersion = CONVERT(binary(8), 0x0000000000000000),
        Guid      = e.DataObjectGuid,

        /* ------------------------------------------------------------
           Existing payload (kept intact)
        ------------------------------------------------------------ */
        e.DataObjectGuid,
        e.EntityTypeId,
        e.OrganisationalUnitId,
        e.ResolvedFrom,

        e.WorkflowId,

        e.TransitionId,
        e.TransitionGuid,
        e.TransitionDateTimeUtc,
        e.StatusId,
        e.WorkflowStatusGuid,
        e.WorkflowStatusName,
        e.TransitionComment,

        e.ActorIdentityId,
        e.SurveyorIdentityId,

        AllMappedGroupIdsCsv =
            STUFF((
                SELECT ',' + CONVERT(NVARCHAR(20), ng.GroupID)
                FROM SCore.WorkflowStatusNotificationGroups ng
                WHERE ng.RowStatus NOT IN (0,254)
                  AND ng.WorkflowID = e.WorkflowId
                  AND ng.WorkflowStatusGuid = e.WorkflowStatusGuid
                ORDER BY ng.GroupID
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 1, ''),

        AllMappedGroupCodesCsv =
            STUFF((
                SELECT ',' + g.Code
                FROM SCore.WorkflowStatusNotificationGroups ng
                JOIN SCore.Groups g
                    ON g.ID = ng.GroupID
                   AND g.RowStatus NOT IN (0,254)
                WHERE ng.RowStatus NOT IN (0,254)
                  AND ng.WorkflowID = e.WorkflowId
                  AND ng.WorkflowStatusGuid = e.WorkflowStatusGuid
                ORDER BY g.Code
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 1, ''),

        ActionGroupIdsCsv =
            STUFF((
                SELECT ',' + CONVERT(NVARCHAR(20), ng.GroupID)
                FROM SCore.WorkflowStatusNotificationGroups ng
                WHERE ng.RowStatus NOT IN (0,254)
                  AND ng.WorkflowID = e.WorkflowId
                  AND ng.WorkflowStatusGuid = e.WorkflowStatusGuid
                  AND ng.CanAction = 1
                ORDER BY ng.GroupID
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 1, ''),

        ActionGroupCodesCsv =
            STUFF((
                SELECT ',' + g.Code
                FROM SCore.WorkflowStatusNotificationGroups ng
                JOIN SCore.Groups g
                    ON g.ID = ng.GroupID
                   AND g.RowStatus NOT IN (0,254)
                WHERE ng.RowStatus NOT IN (0,254)
                  AND ng.WorkflowID = e.WorkflowId
                  AND ng.WorkflowStatusGuid = e.WorkflowStatusGuid
                  AND ng.CanAction = 1
                ORDER BY g.Code
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 1, ''),

        MatchedActionGroupIdsCsv =
            STUFF((
                SELECT ',' + CONVERT(NVARCHAR(20), ng.GroupID)
                FROM SCore.WorkflowStatusNotificationGroups ng
                JOIN SCore.UserGroups ug
                    ON ug.GroupID = ng.GroupID
                   AND ug.RowStatus NOT IN (0,254)
                   AND ug.IdentityID = @UserId
                WHERE ng.RowStatus NOT IN (0,254)
                  AND ng.WorkflowID = e.WorkflowId
                  AND ng.WorkflowStatusGuid = e.WorkflowStatusGuid
                  AND ng.CanAction = 1
                ORDER BY ng.GroupID
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 1, ''),

        MatchedActionGroupCodesCsv =
            STUFF((
                SELECT ',' + g.Code
                FROM SCore.WorkflowStatusNotificationGroups ng
                JOIN SCore.UserGroups ug
                    ON ug.GroupID = ng.GroupID
                   AND ug.RowStatus NOT IN (0,254)
                   AND ug.IdentityID = @UserId
                JOIN SCore.Groups g
                    ON g.ID = ng.GroupID
                   AND g.RowStatus NOT IN (0,254)
                WHERE ng.RowStatus NOT IN (0,254)
                  AND ng.WorkflowID = e.WorkflowId
                  AND ng.WorkflowStatusGuid = e.WorkflowStatusGuid
                  AND ng.CanAction = 1
                ORDER BY g.Code
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 1, '')
    FROM Eligible e
);
GO