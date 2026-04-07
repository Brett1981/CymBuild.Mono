SET QUOTED_IDENTIFIER, ANSI_NULLS ON
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
        RETURN;

    IF ISNULL(@SendNotification, 0) = 0
        RETURN;

    /* ------------------------------------------------------------
       3) Resolve routing (EntityType + OU) for this DataObjectGuid
          (take a valid row; prefer most recent if duplicates exist)
    ------------------------------------------------------------ */
    DECLARE
        @EntityTypeId            INT,
        @OrganisationalUnitId    INT;

    SELECT TOP (1)
        @EntityTypeId = r.EntityTypeId,
        @OrganisationalUnitId = r.OrganisationalUnitId
    FROM SCore.WF_Auth_DataObjectRouting r
    WHERE r.DataObjectGuid = @DataObjectGuid
      AND r.EntityTypeId IS NOT NULL
      AND r.OrganisationalUnitId IS NOT NULL
    ORDER BY r.DataObjectGuid; -- stable tie-break (replace with a real timestamp/ID if the table has one)

    IF @EntityTypeId IS NULL OR @OrganisationalUnitId IS NULL
        RETURN;

    /* ------------------------------------------------------------
       4) Resolve WorkflowId for this status within (EntityType, OU)
          IMPORTANT FIX:
          - Allow workflows defined for OU = -1 (All) to match real OU records.
    ------------------------------------------------------------ */
    DECLARE @WorkflowId INT;

    SELECT TOP (1)
        @WorkflowId = wf.ID
    FROM SCore.Workflow wf
    JOIN SCore.WorkflowTransition wft
        ON wft.WorkflowID = wf.ID
    WHERE wf.RowStatus NOT IN (0,254)
      AND wft.RowStatus NOT IN (0,254)
      AND ISNULL(wf.Enabled, 1) = 1
      AND ISNULL(wft.Enabled, 1) = 1
      AND wf.EntityTypeID = @EntityTypeId
      AND wf.OrganisationalUnitId IN (@OrganisationalUnitId, -1)  -- ✅ OU fallback
      AND wft.ToStatusID = @StatusId
    ORDER BY
        CASE WHEN wf.OrganisationalUnitId = @OrganisationalUnitId THEN 0 ELSE 1 END, -- prefer exact OU
        wf.ID DESC;

    IF @WorkflowId IS NULL
        RETURN;

    /* ------------------------------------------------------------
       5) Resolve notification target groups for (WorkflowId, StatusGuid)
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

            @WorkflowId AS workflowId,

            @StatusId AS statusId,
            @StatusGuid AS statusGuid,
            @StatusName AS statusName,

            @TransitionId AS transitionId,
            @TransitionGuid AS transitionGuid,

            @OldStatusId AS oldStatusId,
            @Comment AS comment,

            @CreatedByUserId AS actorIdentityId,
            @SurveyorUserId AS surveyorIdentityId,

            @TargetGroupIdsCsv AS targetGroupIdsCsv
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