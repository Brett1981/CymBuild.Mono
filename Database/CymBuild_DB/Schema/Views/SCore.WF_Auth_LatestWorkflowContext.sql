SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

/* =============================================================================
   VIEW: SCore.WF_Auth_LatestWorkflowContext

   Purpose:
   - Provide a single, reusable “latest workflow context” dataset for queues.
   - Works for ANY entity type, because it keys off:
       * DataObjectGuid (record guid)
       * routing (EntityTypeId + OU) via SCore.WF_Auth_DataObjectRouting
       * latest transition via SCore.DataObjectTransition

   Returns (core):
   - DataObjectGuid, EntityTypeId, OrganisationalUnitId
   - LatestTransitionGuid, LatestTransitionUtc
   - LatestStatusId, LatestWorkflowStatusGuid, LatestWorkflowStatusName
   - IsActive/IsComplete flags from WorkflowStatus
   - AuthorisationNeeded (queue filter)
   - WorkflowId resolved for this (EntityTypeId, OU, ToStatusId)

   Notes:
   - If routing is missing OR no workflow matches, WorkflowId will be NULL.
   - We deliberately do not throw; consumers decide what to do.
============================================================================= */
CREATE VIEW [SCore].[WF_Auth_LatestWorkflowContext]
    --WITH SCHEMABINDING
AS
WITH Routing AS
(
    SELECT
        r.DataObjectGuid,
        r.EntityTypeId,
        r.OrganisationalUnitId,
        r.ResolvedFrom
    FROM SCore.WF_Auth_DataObjectRouting r
    WHERE r.OrganisationalUnitId IS NOT NULL
),
LatestTransition AS
(
    SELECT
        dot.DataObjectGuid,
        dot.Guid       AS LatestTransitionGuid,
        dot.DateTimeUTC AS LatestTransitionUtc,
        dot.StatusID   AS LatestStatusId,
        dot.CreatedByUserId,
        dot.Comment,

        /* Identify latest row per DataObjectGuid */
        ROW_NUMBER() OVER (PARTITION BY dot.DataObjectGuid ORDER BY dot.ID DESC) AS rn
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
        lt.CreatedByUserId,
        lt.Comment
    FROM LatestTransition lt
    WHERE lt.rn = 1
),
StatusMeta AS
(
    SELECT
        ws.ID     AS StatusId,
        ws.Guid   AS StatusGuid,
        ws.Name   AS StatusName,
        ws.IsActiveStatus,
        ws.IsCompleteStatus,
        ws.AuthorisationNeeded,
        ws.SendNotification
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
)
SELECT
    r.DataObjectGuid,
    r.EntityTypeId,
    r.OrganisationalUnitId,
    r.ResolvedFrom,

    l.LatestTransitionGuid,
    l.LatestTransitionUtc,
    l.LatestStatusId,

    sm.StatusGuid AS LatestWorkflowStatusGuid,
    sm.StatusName AS LatestWorkflowStatusName,
    sm.IsActiveStatus  AS LatestIsActiveStatus,
    sm.IsCompleteStatus AS LatestIsCompleteStatus,
    sm.AuthorisationNeeded,
    sm.SendNotification,

    /* Resolved workflow context (may be NULL if not found) */
    wf.ID AS WorkflowId,

    /* Optional diagnostic payload */
    l.CreatedByUserId,
    l.Comment
FROM Routing r
LEFT JOIN Latest l
    ON l.DataObjectGuid = r.DataObjectGuid
LEFT JOIN StatusMeta sm
    ON sm.StatusId = l.LatestStatusId
LEFT JOIN SCore.Workflow wf
    ON wf.RowStatus NOT IN (0,254)
   AND ISNULL(wf.Enabled, 1) = 1
   AND wf.EntityTypeID = r.EntityTypeId
   AND wf.OrganisationalUnitId = r.OrganisationalUnitId
LEFT JOIN SCore.WorkflowTransition wft
    ON wft.RowStatus NOT IN (0,254)
   AND ISNULL(wft.Enabled, 1) = 1
   AND wft.WorkflowID = wf.ID
   AND wft.ToStatusID = l.LatestStatusId;
GO