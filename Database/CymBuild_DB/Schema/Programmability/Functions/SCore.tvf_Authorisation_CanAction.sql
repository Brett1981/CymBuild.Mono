SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_Authorisation_CanAction]
(
    @UserId INT,
    @DataObjectGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
(
    WITH LatestTransition AS
    (
        SELECT TOP (1)
            dot.Guid            AS LatestTransitionGuid,
            dot.ID              AS LatestTransitionId,
            dot.DateTimeUTC     AS LatestTransitionUtc,
            dot.StatusID        AS LatestStatusId,
            dot.OldStatusID     AS LatestOldStatusId,
            dot.CreatedByUserId AS CreatedByUserId,
            dot.Comment         AS Comment
        FROM SCore.DataObjectTransition dot
        WHERE dot.RowStatus NOT IN (0,254)
          AND dot.DataObjectGuid = @DataObjectGuid
        ORDER BY dot.ID DESC
    ),
    StatusMeta AS
    (
        SELECT
            lt.LatestTransitionGuid,
            lt.LatestTransitionId,
            lt.LatestTransitionUtc,
            lt.LatestStatusId,
            lt.LatestOldStatusId,
            lt.CreatedByUserId,
            lt.Comment,

            ws.Guid                AS LatestStatusGuid,
            ws.Name                AS LatestStatusName,
            ws.AuthorisationNeeded AS AuthorisationNeeded,
            ws.SendNotification    AS SendNotification,
            ws.IsActiveStatus      AS LatestIsActiveStatus,
            ws.IsCompleteStatus    AS LatestIsCompleteStatus
        FROM LatestTransition lt
        JOIN SCore.WorkflowStatus ws
          ON ws.ID = lt.LatestStatusId
         AND ws.RowStatus NOT IN (0,254)
    ),
    Routing AS
    (
        /* Ensure a single routing row per DataObjectGuid to avoid duplicates */
        SELECT TOP (1)
            sm.LatestTransitionGuid,
            sm.LatestTransitionId,
            sm.LatestTransitionUtc,
            sm.LatestStatusId,
            sm.LatestOldStatusId,
            sm.CreatedByUserId,
            sm.Comment,
            sm.LatestStatusGuid,
            sm.LatestStatusName,
            sm.AuthorisationNeeded,
            sm.SendNotification,
            sm.LatestIsActiveStatus,
            sm.LatestIsCompleteStatus,

            r.EntityTypeId,
            r.OrganisationalUnitId,
            r.ResolvedFrom
        FROM StatusMeta sm
        JOIN SCore.WF_Auth_DataObjectRouting r
          ON r.DataObjectGuid = @DataObjectGuid
        WHERE r.OrganisationalUnitId IS NOT NULL
          AND r.EntityTypeId IS NOT NULL
        ORDER BY r.ResolvedFrom, r.EntityTypeId, r.OrganisationalUnitId
    ),
    WorkflowResolved AS
    (
        /* Resolve which workflow applies for this (EntityType, OU) and status */
        SELECT TOP (1)
            rt.LatestTransitionGuid,
            rt.LatestTransitionId,
            rt.LatestTransitionUtc,
            rt.LatestStatusId,
            rt.LatestOldStatusId,
            rt.CreatedByUserId,
            rt.Comment,
            rt.LatestStatusGuid,
            rt.LatestStatusName,
            rt.AuthorisationNeeded,
            rt.SendNotification,
            rt.LatestIsActiveStatus,
            rt.LatestIsCompleteStatus,
            rt.EntityTypeId,
            rt.OrganisationalUnitId,
            rt.ResolvedFrom,

            wf.ID   AS WorkflowId,
            wf.Name AS WorkflowName
        FROM Routing rt
        JOIN SCore.Workflow wf
          ON wf.RowStatus NOT IN (0,254)
         AND ISNULL(wf.Enabled, 1) = 1
         AND wf.EntityTypeID = rt.EntityTypeId
         AND wf.OrganisationalUnitId = rt.OrganisationalUnitId
        JOIN SCore.WorkflowTransition wft
          ON wft.RowStatus NOT IN (0,254)
         AND ISNULL(wft.Enabled, 1) = 1
         AND wft.WorkflowID = wf.ID
         AND wft.ToStatusID = rt.LatestStatusId
        ORDER BY wf.ID DESC
    ),
    ActionGroups AS
    (
        SELECT
            wr.LatestTransitionGuid,
            wr.LatestTransitionId,
            wr.LatestTransitionUtc,
            wr.LatestStatusId,
            wr.LatestStatusGuid,
            wr.LatestStatusName,
            wr.LatestOldStatusId,
            wr.CreatedByUserId,
            wr.Comment,

            wr.AuthorisationNeeded,
            wr.SendNotification,
            wr.LatestIsActiveStatus,
            wr.LatestIsCompleteStatus,

            wr.EntityTypeId,
            wr.OrganisationalUnitId,
            wr.ResolvedFrom,

            wr.WorkflowId,
            wr.WorkflowName,

            map.GroupID,
            g.Code AS GroupCode,
            g.Name AS GroupName
        FROM WorkflowResolved wr
        JOIN SCore.WorkflowStatusNotificationGroups map
          ON map.RowStatus NOT IN (0,254)
         AND map.WorkflowID = wr.WorkflowId
         AND map.WorkflowStatusGuid = wr.LatestStatusGuid
         AND map.CanAction = 1
        JOIN SCore.Groups g
          ON g.RowStatus NOT IN (0,254)
         AND g.ID = map.GroupID
    ),
    UserMembership AS
    (
        SELECT
            ag.LatestTransitionGuid,
            ag.LatestTransitionId,
            ag.LatestTransitionUtc,
            ag.LatestStatusId,
            ag.LatestStatusGuid,
            ag.LatestStatusName,
            ag.LatestOldStatusId,
            ag.CreatedByUserId,
            ag.Comment,

            ag.AuthorisationNeeded,
            ag.SendNotification,
            ag.LatestIsActiveStatus,
            ag.LatestIsCompleteStatus,

            ag.EntityTypeId,
            ag.OrganisationalUnitId,
            ag.ResolvedFrom,

            ag.WorkflowId,
            ag.WorkflowName,

            ag.GroupID,
            ag.GroupCode,
            ag.GroupName,

            CASE WHEN EXISTS
            (
                SELECT 1
                FROM SCore.UserGroups ug
                WHERE ug.RowStatus NOT IN (0,254)
                  AND ug.GroupID = ag.GroupID
                  AND ug.IdentityID = @UserId
            )
            THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS UserIsInActionGroup
        FROM ActionGroups ag
    )
    SELECT
        @DataObjectGuid AS DataObjectGuid,

        EntityTypeId,
        OrganisationalUnitId,
        ResolvedFrom,

        LatestTransitionGuid,
        LatestTransitionId,
        LatestTransitionUtc,

        LatestStatusId,
        LatestStatusGuid,
        LatestStatusName,
        LatestOldStatusId,

        CreatedByUserId,
        Comment,

        WorkflowId,
        WorkflowName,

        AuthorisationNeeded,
        SendNotification,
        LatestIsActiveStatus,
        LatestIsCompleteStatus,

        GroupID,
        GroupCode,
        GroupName,

        UserIsInActionGroup,

        CASE
            WHEN ISNULL(AuthorisationNeeded, 0) = 1
             AND UserIsInActionGroup = 1
            THEN CAST(1 AS bit)
            ELSE CAST(0 AS bit)
        END AS CanActionThisRecord
    FROM UserMembership
);
GO