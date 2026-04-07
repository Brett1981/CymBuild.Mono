SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCore].[IntegrationOutboxNotificationRecipients]
    --WITH SCHEMABINDING
AS
WITH Outbox AS
(
    SELECT
        o.ID                AS OutboxId,
        o.Guid              AS OutboxGuid,
        o.CreatedOnUtc,
        o.EventType,
        o.PayloadJson,
        o.PublishedOnUtc,
        o.PublishAttempts,
        o.LastError,

        /* Keys - support camelCase OR PascalCase */
        COALESCE(
            TRY_CONVERT(uniqueidentifier, JSON_VALUE(o.PayloadJson, '$.dataObjectGuid')),
            TRY_CONVERT(uniqueidentifier, JSON_VALUE(o.PayloadJson, '$.DataObjectGuid'))
        ) AS DataObjectGuid,

        COALESCE(
            TRY_CONVERT(int, JSON_VALUE(o.PayloadJson, '$.transitionId')),
            TRY_CONVERT(int, JSON_VALUE(o.PayloadJson, '$.TransitionId'))
        ) AS TransitionId,

        COALESCE(
            TRY_CONVERT(int, JSON_VALUE(o.PayloadJson, '$.workflowId')),
            TRY_CONVERT(int, JSON_VALUE(o.PayloadJson, '$.WorkflowId'))
        ) AS WorkflowId,

        /* Prefer guid if present */
        COALESCE(
            TRY_CONVERT(uniqueidentifier, JSON_VALUE(o.PayloadJson, '$.statusGuid')),
            TRY_CONVERT(uniqueidentifier, JSON_VALUE(o.PayloadJson, '$.WorkflowStatusGuid')),
            TRY_CONVERT(uniqueidentifier, JSON_VALUE(o.PayloadJson, '$.StatusGuid'))
        ) AS StatusGuidFromPayload,

        COALESCE(
            TRY_CONVERT(int, JSON_VALUE(o.PayloadJson, '$.statusId')),
            TRY_CONVERT(int, JSON_VALUE(o.PayloadJson, '$.StatusId'))
        ) AS StatusIdFromPayload
    FROM SCore.IntegrationOutbox o
    WHERE o.RowStatus NOT IN (0,254)
      AND o.EventType IN (N'WorkflowStatusNotification', N'WorkflowNotification')
),
StatusResolved AS
(
    SELECT
        ob.OutboxId,
        ob.OutboxGuid,
        ob.CreatedOnUtc,
        ob.EventType,
        ob.PayloadJson,
        ob.PublishedOnUtc,
        ob.PublishAttempts,
        ob.LastError,
        ob.DataObjectGuid,
        ob.TransitionId,
        ob.WorkflowId,
        ob.StatusGuidFromPayload,
        ob.StatusIdFromPayload,

        COALESCE(ob.StatusGuidFromPayload, ws.Guid) AS WorkflowStatusGuidResolved
    FROM Outbox ob
    LEFT JOIN SCore.WorkflowStatus ws
        ON ws.RowStatus NOT IN (0,254)
       AND ob.StatusGuidFromPayload IS NULL
       AND ob.StatusIdFromPayload IS NOT NULL
       AND ws.ID = ob.StatusIdFromPayload
),
Routing AS
(
    SELECT
        sr.OutboxId,
        sr.OutboxGuid,
        sr.CreatedOnUtc,
        sr.EventType,
        sr.PayloadJson,
        sr.PublishedOnUtc,
        sr.PublishAttempts,
        sr.LastError,
        sr.DataObjectGuid,
        sr.TransitionId,
        sr.WorkflowId,
        sr.WorkflowStatusGuidResolved,

        map.GroupID,
        map.CanAction
    FROM StatusResolved sr
    JOIN SCore.WorkflowStatusNotificationGroups map
        ON map.RowStatus NOT IN (0,254)
       AND map.WorkflowID = sr.WorkflowId
       AND map.WorkflowStatusGuid = sr.WorkflowStatusGuidResolved
),
Users AS
(
    SELECT
        r.OutboxId,
        r.OutboxGuid,
        r.CreatedOnUtc,
        r.EventType,
        r.PayloadJson,
        r.PublishedOnUtc,
        r.PublishAttempts,
        r.LastError,
        r.DataObjectGuid,
        r.TransitionId,
        r.WorkflowId,
        r.WorkflowStatusGuidResolved,

        r.GroupID,
        r.CanAction,

        ug.IdentityID,
        g.Code      AS GroupCode,
        g.Name      AS GroupName,
        i.FullName,
        i.EmailAddress
    FROM Routing r
    JOIN SCore.UserGroups ug
        ON ug.RowStatus NOT IN (0,254)
       AND ug.GroupID = r.GroupID
    JOIN SCore.Groups g
        ON g.RowStatus NOT IN (0,254)
       AND g.ID = ug.GroupID
    JOIN SCore.Identities i
        ON i.RowStatus NOT IN (0,254)
       AND i.IsActive = 1
       AND i.ID = ug.IdentityID
)
SELECT
    u.OutboxId,
    u.OutboxGuid,
    u.CreatedOnUtc,
    u.EventType,
    u.PublishedOnUtc,
    u.PublishAttempts,
    u.LastError,

    u.DataObjectGuid,
    u.TransitionId,
    u.WorkflowId,
    u.WorkflowStatusGuidResolved AS WorkflowStatusGuid,

    u.GroupID,
    u.GroupCode,
    u.GroupName,
    u.CanAction,

    u.IdentityID,
    u.FullName,
    u.EmailAddress
FROM Users u;
GO