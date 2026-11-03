/*
    CYB-515 (26.4 port of LIVE 26.2 commit 52eb8f94 / CB262_WFN_R1)
    Workflow notification enqueue: explicit outcome codes + trigger diagnostics.

    - SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification gains optional OUTPUT
      parameters @OutcomeCode / @OutcomeMessage / @OutboxId (existing callers unaffected).
      WorkflowOutboxRepository (API) reads them: Enqueued/AlreadyEnqueued = success,
      NotLatestTransition/NotificationDisabled = terminal no-send, anything else is retried
      with LastError instead of being silently dropped.
    - tr_DataObjectTransition_EnqueueWorkflowStatusNotification logs non-enqueued outcomes and
      swallowed errors to SCore.WorkflowNotificationQueueErrorLog (never blocks the transition).
    - tr_DataObjectTransition_QueueWorkflowNotifications restores the diagnostics WHERE filter
      so ordinary non-notifying / already-queued transitions are not logged as errors.

    Trigger bodies are taken verbatim from release/26.2 (LIVE) Schema/Tables/SCore.DataObjectTransition.sql.
    Apply to the current DEV database first, then run the schema workbench -SyncSource so the
    generated Schema/Tables/SCore.DataObjectTransition.sql picks the triggers up (it must not be
    hand-edited). Idempotent: safe to re-run. Deploy BEFORE the API build that contains the
    WorkflowOutboxRepository change.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'SCore.DataObjectTransition', N'U') IS NULL
    THROW 60000, N'Required table SCore.DataObjectTransition does not exist.', 1;
IF OBJECT_ID(N'SCore.WorkflowNotificationQueue', N'U') IS NULL
    THROW 60000, N'Required table SCore.WorkflowNotificationQueue does not exist.', 1;
IF OBJECT_ID(N'SCore.WorkflowNotificationQueueErrorLog', N'U') IS NULL
    THROW 60000, N'Required table SCore.WorkflowNotificationQueueErrorLog does not exist.', 1;
GO

PRINT N'CYB-515: SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification on ' + DB_NAME();
GO
/* =============================================================================
   SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification

   Writes:
   - One SCore.IntegrationOutbox row per transition IF:
       WorkflowStatus.SendNotification = 1
       AND workflow can be resolved for (EntityTypeId, OU or OU=-1(All), StatusId)
       AND at least one target notification group exists for (WorkflowId, StatusGuid)

   NOTE:
   - PayloadJson uses camelCase keys (important for JSON_VALUE and Kafka contracts)
============================================================================= */
CREATE OR ALTER PROCEDURE [SCore].[IntegrationOutbox_EnqueueWorkflowStatusNotification]
(
    @TransitionGuid UNIQUEIDENTIFIER,
    @OutcomeCode NVARCHAR(64) = NULL OUTPUT,
    @OutcomeMessage NVARCHAR(2000) = NULL OUTPUT,
    @OutboxId BIGINT = NULL OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @OutcomeCode = N'Unknown';
    SET @OutcomeMessage = NULL;
    SET @OutboxId = NULL;

    /* ------------------------------------------------------------
       1) Load transition (the inserted row)
    ------------------------------------------------------------ */
    DECLARE
        @TransitionId       INT,
        @DataObjectGuid     UNIQUEIDENTIFIER,
        @StatusId           INT,
        @OldStatusId        INT,
        @Comment            NVARCHAR(MAX),
        @CreatedByUserId    INT,
        @SurveyorUserId     INT,
        @DateTimeUtc        DATETIME2(7);

    SELECT TOP (1)
        @TransitionId      = dot.ID,
        @DataObjectGuid    = dot.DataObjectGuid,
        @StatusId          = dot.StatusID,
        @OldStatusId       = dot.OldStatusID,
        @Comment           = dot.Comment,
        @CreatedByUserId   = dot.CreatedByUserId,
        @SurveyorUserId    = ISNULL(dot.SurveyorUserId, -1),
        @DateTimeUtc       = dot.DateTimeUTC
    FROM SCore.DataObjectTransition dot
    WHERE dot.Guid = @TransitionGuid
      AND dot.RowStatus NOT IN (0,254);

    IF @DataObjectGuid IS NULL OR @StatusId IS NULL
    BEGIN
        SET @OutcomeCode = N'TransitionNotFound';
        SET @OutcomeMessage = N'The transition was not found or is inactive.';
        RETURN;
    END;

    /* ------------------------------------------------------------
       1b) LATEST-ONLY rule (strict):
           Only enqueue if THIS transition is the latest for the record
           AND the latest status is marked SendNotification=1.
    ------------------------------------------------------------ */
    DECLARE
        @LatestTransitionGuid UNIQUEIDENTIFIER,
        @LatestStatusId INT,
        @LatestSendNotification BIT;

    SELECT TOP (1)
        @LatestTransitionGuid = dot2.Guid,
        @LatestStatusId = dot2.StatusID,
        @LatestSendNotification = ISNULL(ws2.SendNotification, 0)
    FROM SCore.DataObjectTransition dot2
    JOIN SCore.WorkflowStatus ws2
        ON ws2.ID = dot2.StatusID
       AND ws2.RowStatus NOT IN (0,254)
    WHERE dot2.RowStatus NOT IN (0,254)
      AND dot2.DataObjectGuid = @DataObjectGuid
    ORDER BY dot2.DateTimeUTC DESC, dot2.ID DESC;

    IF @LatestTransitionGuid IS NULL
    BEGIN
        SET @OutcomeCode = N'LatestTransitionNotFound';
        SET @OutcomeMessage = N'No active latest transition could be resolved for the data object.';
        RETURN;
    END;

    IF @LatestTransitionGuid <> @TransitionGuid
    BEGIN
        SET @OutcomeCode = N'NotLatestTransition';
        SET @OutcomeMessage = CONCAT(
            N'The transition is not current. LatestTransitionGuid=',
            CONVERT(NVARCHAR(36), @LatestTransitionGuid),
            N'.');
        RETURN;
    END;

    IF ISNULL(@LatestSendNotification, 0) = 0
    BEGIN
        SET @OutcomeCode = N'NotificationDisabled';
        SET @OutcomeMessage = N'The latest workflow status is not configured to send a notification.';
        RETURN;
    END;

    /* ------------------------------------------------------------
       1c) IDEMPOTENCY rule:
           If we've already enqueued an outbox item for this transition,
           do nothing (prevents double Kafka notifications).
    ------------------------------------------------------------ */
    SELECT TOP (1)
        @OutboxId = o.ID
    FROM SCore.IntegrationOutbox o
    WHERE o.RowStatus NOT IN (0,254)
      AND o.EventType = N'WorkflowStatusNotification'
      AND
      (
          TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(o.PayloadJson, '$.transitionGuid')) = @TransitionGuid
          OR TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(o.PayloadJson, '$.TransitionGuid')) = @TransitionGuid
      )
    ORDER BY o.ID DESC;

    IF @OutboxId IS NOT NULL
    BEGIN
        SET @OutcomeCode = N'AlreadyEnqueued';
        SET @OutcomeMessage = N'An active workflow notification outbox item already exists for this transition.';
        RETURN;
    END;

    /* ------------------------------------------------------------
       2) Resolve status metadata (ONLY SendNotification = 1)
    ------------------------------------------------------------ */
    DECLARE
        @StatusGuid        UNIQUEIDENTIFIER,
        @StatusName        NVARCHAR(200),
        @SendNotification  BIT;

    SELECT TOP (1)
        @StatusGuid       = ws.Guid,
        @StatusName       = ws.Name,
        @SendNotification = ISNULL(ws.SendNotification, 0)
    FROM SCore.WorkflowStatus ws
    WHERE ws.ID = @StatusId
      AND ws.RowStatus NOT IN (0,254);

    IF @StatusGuid IS NULL
    BEGIN
        SET @OutcomeCode = N'StatusNotFound';
        SET @OutcomeMessage = N'The active workflow status could not be resolved.';
        RETURN;
    END;

    IF ISNULL(@SendNotification, 0) = 0
    BEGIN
        SET @OutcomeCode = N'NotificationDisabled';
        SET @OutcomeMessage = N'The workflow status is not configured to send a notification.';
        RETURN;
    END;

    /* Old status metadata */
    DECLARE
        @OldStatusGuid UNIQUEIDENTIFIER = NULL,
        @OldStatusName NVARCHAR(200) = NULL;

    IF @OldStatusId IS NOT NULL
    BEGIN
        SELECT TOP (1)
            @OldStatusGuid = ws.Guid,
            @OldStatusName = ws.Name
        FROM SCore.WorkflowStatus ws
        WHERE ws.ID = @OldStatusId
          AND ws.RowStatus NOT IN (0,254);
    END;

    /* ------------------------------------------------------------
       3) Resolve routing (EntityType + OU) for this DataObjectGuid
    ------------------------------------------------------------ */
    DECLARE
        @EntityTypeId            INT,
        @OrganisationalUnitId    INT,
        @OrganisationalUnitName  NVARCHAR(200) = NULL;

    SELECT TOP (1)
        @EntityTypeId = r.EntityTypeId,
        @OrganisationalUnitId = r.OrganisationalUnitId
    FROM SCore.WF_Auth_DataObjectRouting r
    WHERE r.DataObjectGuid = @DataObjectGuid
      AND r.EntityTypeId IS NOT NULL
      AND r.OrganisationalUnitId IS NOT NULL
    ORDER BY r.DataObjectGuid;

    IF @EntityTypeId IS NULL OR @OrganisationalUnitId IS NULL
    BEGIN
        SET @OutcomeCode = N'RoutingNotResolved';
        SET @OutcomeMessage = N'Entity type and organisational-unit routing could not be resolved for the data object.';
        RETURN;
    END;

    SELECT TOP (1)
        @OrganisationalUnitName = ou.Name
    FROM SCore.OrganisationalUnits ou
    WHERE ou.RowStatus NOT IN (0,254)
      AND ou.ID = @OrganisationalUnitId;

    /* ------------------------------------------------------------
       3b) Resolve record-specific payload enrichment
           CYB-4: add enquiry location + quoting deadline to payload
    ------------------------------------------------------------ */
    DECLARE
        @DisplayAddress NVARCHAR(1000) = NULL,
        @DueDateUtc DATETIME2(7) = NULL,
        @DueDateDisplay NVARCHAR(50) = NULL;

    /*
        Enquiry-specific enrichment.
        We only populate these fields when the transitioned record is an SSop.Enquiries row.
        DataObjectGuid is the Enquiry.Guid for major entity rows in CymBuild.
    */
    IF EXISTS
    (
        SELECT 1
        FROM SSop.Enquiries e
        WHERE e.Guid = @DataObjectGuid
          AND e.RowStatus NOT IN (0,254)
    )
    BEGIN
        SELECT TOP (1)
            @DisplayAddress =
                NULLIF(
                    LTRIM(RTRIM(
                        COALESCE(NULLIF(e.PropertyNameNumber, N''), N'')
                        + CASE WHEN NULLIF(e.PropertyNameNumber, N'') IS NOT NULL AND NULLIF(e.PropertyAddressLine1, N'') IS NOT NULL THEN N', ' ELSE N'' END
                        + COALESCE(NULLIF(e.PropertyAddressLine1, N''), N'')
                        + CASE WHEN (NULLIF(e.PropertyNameNumber, N'') IS NOT NULL OR NULLIF(e.PropertyAddressLine1, N'') IS NOT NULL) AND NULLIF(e.PropertyAddressLine2, N'') IS NOT NULL THEN N', ' ELSE N'' END
                        + COALESCE(NULLIF(e.PropertyAddressLine2, N''), N'')
                        + CASE WHEN (NULLIF(e.PropertyNameNumber, N'') IS NOT NULL OR NULLIF(e.PropertyAddressLine1, N'') IS NOT NULL OR NULLIF(e.PropertyAddressLine2, N'') IS NOT NULL) AND NULLIF(e.PropertyAddressLine3, N'') IS NOT NULL THEN N', ' ELSE N'' END
                        + COALESCE(NULLIF(e.PropertyAddressLine3, N''), N'')
                        + CASE WHEN (NULLIF(e.PropertyNameNumber, N'') IS NOT NULL OR NULLIF(e.PropertyAddressLine1, N'') IS NOT NULL OR NULLIF(e.PropertyAddressLine2, N'') IS NOT NULL OR NULLIF(e.PropertyAddressLine3, N'') IS NOT NULL) AND NULLIF(e.PropertyTown, N'') IS NOT NULL THEN N', ' ELSE N'' END
                        + COALESCE(NULLIF(e.PropertyTown, N''), N'')
                        + CASE WHEN (NULLIF(e.PropertyNameNumber, N'') IS NOT NULL OR NULLIF(e.PropertyAddressLine1, N'') IS NOT NULL OR NULLIF(e.PropertyAddressLine2, N'') IS NOT NULL OR NULLIF(e.PropertyAddressLine3, N'') IS NOT NULL OR NULLIF(e.PropertyTown, N'') IS NOT NULL) AND NULLIF(e.PropertyPostCode, N'') IS NOT NULL THEN N', ' ELSE N'' END
                        + COALESCE(NULLIF(e.PropertyPostCode, N''), N'')
                    )),
                    N''
                ),
            @DueDateUtc =
                CASE
                    WHEN e.QuotingDeadlineDate IS NULL THEN NULL
                    ELSE CAST(e.QuotingDeadlineDate AS DATETIME2(7))
                END,
            @DueDateDisplay =
                CASE
                    WHEN e.QuotingDeadlineDate IS NULL THEN NULL
                    ELSE CONVERT(NVARCHAR(11), CAST(e.QuotingDeadlineDate AS DATE), 106)
                END
        FROM SSop.Enquiries e
        WHERE e.Guid = @DataObjectGuid
          AND e.RowStatus NOT IN (0,254);
    END;

    /* ------------------------------------------------------------
       4) Resolve WorkflowId (OU=-1 fallback kept)
    ------------------------------------------------------------ */
    DECLARE
        @WorkflowId INT,
        @WorkflowName NVARCHAR(200) = NULL;

    SELECT TOP (1)
        @WorkflowId = wf.ID,
        @WorkflowName = wf.Name
    FROM SCore.Workflow wf
    JOIN SCore.WorkflowTransition wft
        ON wft.WorkflowID = wf.ID
    WHERE wf.RowStatus NOT IN (0,254)
      AND wft.RowStatus NOT IN (0,254)
      AND ISNULL(wf.Enabled, 1) = 1
      AND ISNULL(wft.Enabled, 1) = 1
      AND wf.EntityTypeID = @EntityTypeId
      AND wf.OrganisationalUnitId IN (@OrganisationalUnitId, -1)
      AND wft.ToStatusID = @StatusId
    ORDER BY
        CASE WHEN wf.OrganisationalUnitId = @OrganisationalUnitId THEN 0 ELSE 1 END,
        wf.ID DESC;

    IF @WorkflowId IS NULL
    BEGIN
        SET @OutcomeCode = N'WorkflowNotResolved';
        SET @OutcomeMessage = CONCAT(
            N'No enabled workflow transition matched EntityTypeId=',
            CONVERT(NVARCHAR(20), @EntityTypeId),
            N', OrganisationalUnitId=',
            CONVERT(NVARCHAR(20), @OrganisationalUnitId),
            N', StatusId=',
            CONVERT(NVARCHAR(20), @StatusId),
            N'.');
        RETURN;
    END;

    /* ------------------------------------------------------------
       5) Resolve notification target groups
    ------------------------------------------------------------ */
    DECLARE @TargetGroupIdsCsv NVARCHAR(MAX);

    SELECT
        @TargetGroupIdsCsv =
            STUFF((
                SELECT ',' + CONVERT(NVARCHAR(20), ng.GroupID)
                FROM SCore.WorkflowStatusNotificationGroups ng
                WHERE ng.RowStatus NOT IN (0,254)
                  AND ng.WorkflowID = @WorkflowId
                  AND ng.WorkflowStatusGuid = @StatusGuid
                ORDER BY ng.GroupID
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 1, '');

    IF @TargetGroupIdsCsv IS NULL OR LTRIM(RTRIM(@TargetGroupIdsCsv)) = ''
    BEGIN
        SET @OutcomeCode = N'NotificationGroupsNotConfigured';
        SET @OutcomeMessage = CONCAT(
            N'No active workflow notification groups matched WorkflowId=',
            CONVERT(NVARCHAR(20), @WorkflowId),
            N' and StatusGuid=',
            CONVERT(NVARCHAR(36), @StatusGuid),
            N'.');
        RETURN;
    END;

    DECLARE @TargetGroupsJson NVARCHAR(MAX);

    SELECT @TargetGroupsJson =
    (
        SELECT
            ng.GroupID AS groupId,
            g.Code     AS groupCode,
            g.Name     AS groupName,
            CONVERT(bit, ISNULL(ng.CanAction, 0)) AS canAction
        FROM SCore.WorkflowStatusNotificationGroups ng
        JOIN SCore.Groups g
            ON g.RowStatus NOT IN (0,254)
           AND g.ID = ng.GroupID
        WHERE ng.RowStatus NOT IN (0,254)
          AND ng.WorkflowID = @WorkflowId
          AND ng.WorkflowStatusGuid = @StatusGuid
        ORDER BY ng.GroupID
        FOR JSON PATH
    );

    /* ------------------------------------------------------------
       5b) Actor / Surveyor identity details
    ------------------------------------------------------------ */
    DECLARE
        @ActorName NVARCHAR(200) = NULL,
        @ActorEmail NVARCHAR(320) = NULL,
        @SurveyorName NVARCHAR(200) = NULL,
        @SurveyorEmail NVARCHAR(320) = NULL;

    SELECT TOP (1)
        @ActorName = i.FullName,
        @ActorEmail = i.EmailAddress
    FROM SCore.Identities i
    WHERE i.RowStatus NOT IN (0,254)
      AND i.IsActive = 1
      AND i.ID = @CreatedByUserId;

    IF @SurveyorUserId IS NOT NULL AND @SurveyorUserId <> -1
    BEGIN
        SELECT TOP (1)
            @SurveyorName = i.FullName,
            @SurveyorEmail = i.EmailAddress
        FROM SCore.Identities i
        WHERE i.RowStatus NOT IN (0,254)
          AND i.IsActive = 1
          AND i.ID = @SurveyorUserId;
    END;

    /* ------------------------------------------------------------
       6) Build payload JSON (camelCase keys)
    ------------------------------------------------------------ */
    DECLARE @Payload NVARCHAR(MAX);

    SET @Payload =
    (
        SELECT
            NEWID() AS eventGuid,
            N'WorkflowStatusNotification' AS eventType,

            @DateTimeUtc AS occurredOnUtc,

            @DataObjectGuid AS dataObjectGuid,
            @EntityTypeId AS entityTypeId,
            @OrganisationalUnitId AS organisationalUnitId,
            @OrganisationalUnitName AS organisationalUnitName,

            @WorkflowId AS workflowId,
            @WorkflowName AS workflowName,

            @StatusId AS statusId,
            @StatusGuid AS statusGuid,
            @StatusName AS statusName,

            @OldStatusId AS oldStatusId,
            @OldStatusGuid AS oldStatusGuid,
            @OldStatusName AS oldStatusName,

            @TransitionId AS transitionId,
            @TransitionGuid AS transitionGuid,

            @Comment AS comment,

            @CreatedByUserId AS actorIdentityId,
            @ActorName AS actorName,
            @ActorEmail AS actorEmail,

            @SurveyorUserId AS surveyorIdentityId,
            @SurveyorName AS surveyorName,
            @SurveyorEmail AS surveyorEmail,

            @TargetGroupIdsCsv AS targetGroupIdsCsv,
            JSON_QUERY(@TargetGroupsJson) AS targetGroups,

            /* CYB-4 */
            @DisplayAddress AS displayAddress,
            @DueDateUtc AS dueDateUtc,
            @DueDateDisplay AS dueDateDisplay

        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    /* ------------------------------------------------------------
       7) Write to outbox
    ------------------------------------------------------------ */
    INSERT INTO SCore.IntegrationOutbox
    (
        RowStatus,
        Guid,
        CreatedOnUtc,
        EventType,
        PayloadJson,
        PublishedOnUtc,
        PublishAttempts,
        LastError
    )
    VALUES
    (
        1,
        NEWID(),
        SYSUTCDATETIME(),
        N'WorkflowStatusNotification',
        @Payload,
        NULL,
        0,
        NULL
    );

    SET @OutboxId = CONVERT(BIGINT, SCOPE_IDENTITY());
    SET @OutcomeCode = N'Enqueued';
    SET @OutcomeMessage = N'Workflow notification outbox item created.';
END;
GO

PRINT N'CYB-515: notification triggers on SCore.DataObjectTransition';
GO
CREATE OR ALTER TRIGGER [SCore].[tr_DataObjectTransition_EnqueueWorkflowStatusNotification]
ON [SCore].[DataObjectTransition]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TriggerName SYSNAME =
        N'tr_DataObjectTransition_EnqueueWorkflowStatusNotification';

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
        RETURN;

    -- Only consider active inserted transitions whose destination status sends notifications.
    IF NOT EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN SCore.WorkflowStatus ws
            ON ws.ID = i.StatusID
           AND ws.RowStatus NOT IN (0,254)
        WHERE i.RowStatus NOT IN (0,254)
          AND ISNULL(ws.SendNotification, 0) = 1
    )
        RETURN;

    BEGIN TRY
        DECLARE @TransitionGuid UNIQUEIDENTIFIER;

        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT i.Guid
            FROM inserted i
            JOIN SCore.WorkflowStatus ws
                ON ws.ID = i.StatusID
               AND ws.RowStatus NOT IN (0,254)
            WHERE i.RowStatus NOT IN (0,254)
              AND i.Guid IS NOT NULL
              AND ISNULL(ws.SendNotification, 0) = 1;

        OPEN cur;
        FETCH NEXT FROM cur INTO @TransitionGuid;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE
                @OutcomeCode NVARCHAR(64),
                @OutcomeMessage NVARCHAR(2000),
                @OutboxId BIGINT;

            SET @OutcomeCode = NULL;
            SET @OutcomeMessage = NULL;
            SET @OutboxId = NULL;

            BEGIN TRY
                EXEC [SCore].[IntegrationOutbox_EnqueueWorkflowStatusNotification]
                    @TransitionGuid = @TransitionGuid,
                    @OutcomeCode = @OutcomeCode OUTPUT,
                    @OutcomeMessage = @OutcomeMessage OUTPUT,
                    @OutboxId = @OutboxId OUTPUT;

                IF ISNULL(@OutcomeCode, N'Unknown') NOT IN
                (
                    N'Enqueued',
                    N'AlreadyEnqueued'
                )
                BEGIN
                    BEGIN TRY
                        INSERT INTO SCore.WorkflowNotificationQueueErrorLog
                        (
                            CreatedOnUtc,
                            TriggerName,
                            TransitionGuid,
                            StatusId,
                            ErrorNumber,
                            ErrorSeverity,
                            ErrorState,
                            ErrorLine,
                            ErrorProcedure,
                            ErrorMessage
                        )
                        SELECT
                            SYSUTCDATETIME(),
                            @TriggerName,
                            @TransitionGuid,
                            i.StatusID,
                            0,
                            0,
                            0,
                            0,
                            N'SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification',
                            CONCAT(
                                N'OutcomeCode=', ISNULL(@OutcomeCode, N'Unknown'),
                                N'; OutcomeMessage=', ISNULL(@OutcomeMessage, N''),
                                N'; OutboxId=', ISNULL(CONVERT(NVARCHAR(30), @OutboxId), N'NULL'))
                        FROM inserted i
                        WHERE i.Guid = @TransitionGuid;
                    END TRY
                    BEGIN CATCH
                        -- Diagnostics must never block the workflow transition.
                    END CATCH;
                END;
            END TRY
            BEGIN CATCH
                BEGIN TRY
                    INSERT INTO SCore.WorkflowNotificationQueueErrorLog
                    (
                        CreatedOnUtc,
                        TriggerName,
                        TransitionGuid,
                        StatusId,
                        ErrorNumber,
                        ErrorSeverity,
                        ErrorState,
                        ErrorLine,
                        ErrorProcedure,
                        ErrorMessage
                    )
                    SELECT
                        SYSUTCDATETIME(),
                        @TriggerName,
                        @TransitionGuid,
                        i.StatusID,
                        ERROR_NUMBER(),
                        ERROR_SEVERITY(),
                        ERROR_STATE(),
                        ERROR_LINE(),
                        ERROR_PROCEDURE(),
                        ERROR_MESSAGE()
                    FROM inserted i
                    WHERE i.Guid = @TransitionGuid;
                END TRY
                BEGIN CATCH
                    -- Diagnostics must never block the workflow transition.
                END CATCH;
            END CATCH;

            FETCH NEXT FROM cur INTO @TransitionGuid;
        END;

        CLOSE cur;
        DEALLOCATE cur;
    END TRY
    BEGIN CATCH
        BEGIN TRY
            INSERT INTO SCore.WorkflowNotificationQueueErrorLog
            (
                CreatedOnUtc,
                TriggerName,
                TransitionGuid,
                StatusId,
                ErrorNumber,
                ErrorSeverity,
                ErrorState,
                ErrorLine,
                ErrorProcedure,
                ErrorMessage
            )
            SELECT TOP (1)
                SYSUTCDATETIME(),
                @TriggerName,
                i.Guid,
                i.StatusID,
                ERROR_NUMBER(),
                ERROR_SEVERITY(),
                ERROR_STATE(),
                ERROR_LINE(),
                ERROR_PROCEDURE(),
                ERROR_MESSAGE()
            FROM inserted i
            ORDER BY i.ID;
        END TRY
        BEGIN CATCH
            -- Diagnostics must never block the workflow transition.
        END CATCH;

        RETURN;
    END CATCH
END;
GO

CREATE OR ALTER TRIGGER [SCore].[tr_DataObjectTransition_QueueWorkflowNotifications]
ON [SCore].[DataObjectTransition]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TriggerName SYSNAME = N'tr_DataObjectTransition_QueueWorkflowNotifications';

    -- Session escape hatch
    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_notification_triggers')), 0) = 1)
        RETURN;

    BEGIN TRY

        DECLARE @Eligible TABLE
        (
            TransitionGuid       UNIQUEIDENTIFIER NOT NULL,
            StatusId             INT              NOT NULL,
            DataObjectGuid       UNIQUEIDENTIFIER NOT NULL,
            TransitionRowStatus  INT              NOT NULL,
            SendNotification     BIT              NOT NULL,
            LatestTransitionGuid UNIQUEIDENTIFIER NULL,
            AlreadyQueued        BIT              NOT NULL,
            IsInsert             BIT              NOT NULL,
            StatusChanged        BIT              NOT NULL
        );

        INSERT INTO @Eligible
        (
            TransitionGuid,
            StatusId,
            DataObjectGuid,
            TransitionRowStatus,
            SendNotification,
            LatestTransitionGuid,
            AlreadyQueued,
            IsInsert,
            StatusChanged
        )
        SELECT
            i.Guid,
            i.StatusID,
            i.DataObjectGuid,
            i.RowStatus,
            ISNULL(ws.SendNotification, 0) AS SendNotification,
            latest.LatestGuid,
            CASE WHEN EXISTS (SELECT 1 FROM SCore.WorkflowNotificationQueue q WHERE q.TransitionGuid = i.Guid) THEN 1 ELSE 0 END AS AlreadyQueued,
            CASE WHEN d.Guid IS NULL THEN 1 ELSE 0 END AS IsInsert,
            CASE
                WHEN d.Guid IS NULL THEN 1
                WHEN ISNULL(d.StatusID, -1) <> ISNULL(i.StatusID, -1) THEN 1
                ELSE 0
            END AS StatusChanged
        FROM inserted i
        LEFT JOIN deleted d
            ON d.Guid = i.Guid
        LEFT JOIN SCore.WorkflowStatus ws
            ON ws.ID = i.StatusID
           AND ws.RowStatus NOT IN (0,254)
        OUTER APPLY
        (
            SELECT TOP (1) dot2.Guid AS LatestGuid
            FROM SCore.DataObjectTransition dot2
            WHERE dot2.RowStatus NOT IN (0,254)
              AND dot2.DataObjectGuid = i.DataObjectGuid
            ORDER BY dot2.DateTimeUTC DESC, dot2.ID DESC
        ) latest
        WHERE i.Guid IS NOT NULL;

        -- Only queue when the status is meaningful (SendNotification=1) and it is the latest transition.
        INSERT INTO SCore.WorkflowNotificationQueue (TransitionGuid, StatusId)
        SELECT e.TransitionGuid, e.StatusId
        FROM @Eligible e
        WHERE
            e.TransitionRowStatus NOT IN (0,254)
            AND e.SendNotification = 1
            AND e.LatestTransitionGuid = e.TransitionGuid         -- latest-only
            AND e.AlreadyQueued = 0                               -- idempotent
            AND e.StatusChanged = 1;                              -- catches your "update sets current stage" flow

        -- Diagnostics when nothing queued
        IF @@ROWCOUNT = 0
        BEGIN
            INSERT INTO SCore.WorkflowNotificationQueueErrorLog
            (
                CreatedOnUtc, TriggerName, TransitionGuid, StatusId,
                ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorMessage
            )
            SELECT TOP (5)
                SYSUTCDATETIME(),
                @TriggerName,
                e.TransitionGuid,
                e.StatusId,
                0,0,0,0,NULL,
                CONCAT(
                    N'No queue row inserted. ',
                    N'RowStatus=', e.TransitionRowStatus,
                    N' StatusId=', e.StatusId,
                    N' SendNotification=', CONVERT(nvarchar(5), e.SendNotification),
                    N' IsLatest=', CASE WHEN e.LatestTransitionGuid = e.TransitionGuid THEN N'1' ELSE N'0' END,
                    N' AlreadyQueued=', CASE WHEN e.AlreadyQueued = 1 THEN N'1' ELSE N'0' END,
                    N' IsInsert=', CASE WHEN e.IsInsert = 1 THEN N'1' ELSE N'0' END,
                    N' StatusChanged=', CASE WHEN e.StatusChanged = 1 THEN N'1' ELSE N'0' END,
                    N' LatestGuid=', CONVERT(nvarchar(36), e.LatestTransitionGuid)
                )
            FROM @Eligible e
            WHERE e.TransitionRowStatus NOT IN (0,254)
              AND e.SendNotification = 1
              AND e.AlreadyQueued = 0
              AND e.StatusChanged = 1
            ORDER BY e.TransitionGuid DESC;
        END

    END TRY
    BEGIN CATCH
        BEGIN TRY
            INSERT INTO SCore.WorkflowNotificationQueueErrorLog
            (
                CreatedOnUtc, TriggerName, TransitionGuid, StatusId,
                ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorMessage
            )
            SELECT TOP (1)
                SYSUTCDATETIME(),
                @TriggerName,
                i.Guid,
                i.StatusID,
                ERROR_NUMBER(),
                ERROR_SEVERITY(),
                ERROR_STATE(),
                ERROR_LINE(),
                ERROR_PROCEDURE(),
                ERROR_MESSAGE()
            FROM inserted i;
        END TRY
        BEGIN CATCH
            -- swallow
        END CATCH;
        RETURN;
    END CATCH
END;
GO

PRINT N'CYB-515: done.';
GO
