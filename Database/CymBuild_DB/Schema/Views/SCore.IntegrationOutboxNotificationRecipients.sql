SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SCore].[IntegrationOutboxNotificationRecipients]')
GO
/*
    Recipients of a workflow notification: the active members of the
    notification groups configured on the status (SCore.WorkflowStatusNotificationGroups).

    CYB-588: when an enquiry's bid is decided ("Approved For Quote" or
    "Declined To Quote"), the person who sent it for "Bid Team Review" is also
    a recipient: whoever saved the latest Bid Team Review on that enquiry before
    the decision. They appear as the pseudo-group "Bid review requester"
    (GroupID -1). The API takes distinct email addresses, so a requester who is
    also in the Bid Team gets one email.
*/
CREATE OR ALTER VIEW [SCore].[IntegrationOutboxNotificationRecipients]
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
),
-- CYB-588-BID-REQUESTER: the person who sent the enquiry for Bid Team Review.
Requesters AS
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

        CONVERT(int, -1)                   AS GroupID,
        CONVERT(bit, 0)                    AS CanAction,

        i.ID                               AS IdentityID,
        CONVERT(nvarchar(50), N'BID_REQUESTER')         AS GroupCode,
        CONVERT(nvarchar(250), N'Bid review requester') AS GroupName,
        i.FullName,
        i.EmailAddress
    FROM StatusResolved sr
    CROSS APPLY
    (
        SELECT TOP (1)
            req.CreatedByUserId
        FROM SCore.DataObjectTransition req
        JOIN SCore.WorkflowStatus reqStatus
            ON reqStatus.ID = req.StatusID
        WHERE req.RowStatus NOT IN (0,254)
          AND req.DataObjectGuid = sr.DataObjectGuid
          AND reqStatus.Guid = '675CA95D-F03D-4DBC-B83C-3D21BF138635' -- Bid Team Review
          AND (sr.TransitionId IS NULL OR req.ID < sr.TransitionId)
        ORDER BY req.ID DESC
    ) requester
    JOIN SCore.Identities i
        ON i.RowStatus NOT IN (0,254)
       AND i.IsActive = 1
       AND i.ID = requester.CreatedByUserId
    WHERE sr.WorkflowStatusGuidResolved IN
    (
        '3070A373-0E0A-4261-B942-66CB512EE1B6', -- Approved For Quote
        '60B8D960-8F6C-495D-B2E7-F19EBD5506EE'  -- Declined To Quote
    )
),
AllRecipients AS
(
    SELECT
        u.OutboxId, u.OutboxGuid, u.CreatedOnUtc, u.EventType, u.PayloadJson, u.PublishedOnUtc,
        u.PublishAttempts, u.LastError, u.DataObjectGuid, u.TransitionId, u.WorkflowId,
        u.WorkflowStatusGuidResolved, u.GroupID, u.CanAction, u.IdentityID, u.GroupCode,
        u.GroupName, u.FullName, u.EmailAddress
    FROM Users u

    UNION ALL

    SELECT
        r.OutboxId, r.OutboxGuid, r.CreatedOnUtc, r.EventType, r.PayloadJson, r.PublishedOnUtc,
        r.PublishAttempts, r.LastError, r.DataObjectGuid, r.TransitionId, r.WorkflowId,
        r.WorkflowStatusGuidResolved, r.GroupID, r.CanAction, r.IdentityID, r.GroupCode,
        r.GroupName, r.FullName, r.EmailAddress
    FROM Requesters r
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
FROM AllRecipients u;

GO