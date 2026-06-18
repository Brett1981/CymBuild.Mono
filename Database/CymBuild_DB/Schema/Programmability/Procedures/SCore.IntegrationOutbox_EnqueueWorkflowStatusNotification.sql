SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[IntegrationOutbox_EnqueueWorkflowStatusNotification]')
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
CREATE PROCEDURE [SCore].[IntegrationOutbox_EnqueueWorkflowStatusNotification]
(
    @TransitionGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

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
        RETURN;

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
       OR @LatestTransitionGuid <> @TransitionGuid
       OR ISNULL(@LatestSendNotification, 0) = 0
    BEGIN
        RETURN;
    END;

    /* ------------------------------------------------------------
       1c) IDEMPOTENCY rule:
           If we've already enqueued an outbox item for this transition,
           do nothing (prevents double Kafka notifications).
    ------------------------------------------------------------ */
    IF EXISTS
    (
        SELECT 1
        FROM SCore.IntegrationOutbox o
        WHERE o.RowStatus NOT IN (0,254)
          AND o.EventType = N'WorkflowStatusNotification'
          AND
          (
              TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(o.PayloadJson, '$.transitionGuid')) = @TransitionGuid
              OR TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(o.PayloadJson, '$.TransitionGuid')) = @TransitionGuid
          )
    )
    BEGIN
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

    IF @StatusGuid IS NULL OR ISNULL(@SendNotification, 0) = 0
        RETURN;

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
        RETURN;

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
        RETURN;

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
        RETURN;

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
END;
GO