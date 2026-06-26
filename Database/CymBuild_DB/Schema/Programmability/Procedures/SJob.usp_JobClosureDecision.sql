SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[usp_JobClosureDecision]')
GO


/* =============================================================================
   Proc: SJob.usp_JobClosureDecision

   PURPOSE
   - Hard gate: latest workflow status MUST be Closure Request
   - Approve:
       * optional comment; default "Closure Approved by {USER}"
       * add Approve Closure transition
       * add Completed transition
   - Reject:
       * comment mandatory
       * add Closure Rejected transition
   - Writes a dedicated JobClosureDecision outbox payload for Kafka publishing

   NOTES
   - Does NOT alter the existing WorkflowStatusNotification pipeline
   - Keeps transition behaviour unchanged
   - Payload is aligned to JobClosureDecisionOutboxPayload in API code
============================================================================= */
CREATE PROCEDURE [SJob].[usp_JobClosureDecision]
(
    @JobGuid UNIQUEIDENTIFIER,
    @AuthoriserUserId INT,
    @Decision TINYINT,              -- 1=Approve, 2=Reject
    @Comment NVARCHAR(2000) = NULL,

    @StoredComment NVARCHAR(2000) OUTPUT,
    @DecisionDateTimeUtc DATETIME2(7) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @RC INT = 0,
        @NowUtc DATETIME2(7) = SYSUTCDATETIME();

    SET @DecisionDateTimeUtc = @NowUtc;

    -- Workflow GUIDs (MUST USE EXACT)
    DECLARE
        @Status_Completed UNIQUEIDENTIFIER       = '20D22623-283B-4088-9CEB-D944AC3E6516',
        @Status_ClosureRequest UNIQUEIDENTIFIER  = '5ED9C55A-4E14-44F6-A106-AE0F5C5EC38D',
        @Status_ApproveClosure UNIQUEIDENTIFIER  = 'E6776DB3-812F-4328-B81E-FEFD494EA049',
        @Status_ClosureRejected UNIQUEIDENTIFIER = '48507119-2F28-490C-83A6-CE8F85E5AF7F';

    IF (@Decision NOT IN (1, 2))
        THROW 51001, 'Invalid decision. Use 1=Approve, 2=Reject.', 1;

    IF (@Decision = 2 AND NULLIF(LTRIM(RTRIM(@Comment)), N'') IS NULL)
        THROW 51002, 'Rejection requires a comment.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SJob.Jobs j
        WHERE j.Guid = @JobGuid
          AND j.RowStatus NOT IN (0,254)
    )
        THROW 51003, 'Job not found (or invalid RowStatus).', 1;

    DECLARE @CreatedByUserGuid UNIQUEIDENTIFIER;
    SELECT @CreatedByUserGuid = i.Guid
    FROM SCore.Identities i
    WHERE i.ID = @AuthoriserUserId
      AND i.RowStatus NOT IN (0,254);

    IF (@CreatedByUserGuid IS NULL)
        THROW 51004, 'Authoriser identity not found.', 1;

    DECLARE @SurveyorUserGuid UNIQUEIDENTIFIER;
    SELECT @SurveyorUserGuid = si.Guid
    FROM SJob.Jobs j
    JOIN SCore.Identities si
      ON si.ID = j.SurveyorID
     AND si.RowStatus NOT IN (0,254)
    WHERE j.Guid = @JobGuid
      AND j.RowStatus NOT IN (0,254);

    IF (@SurveyorUserGuid IS NULL)
        THROW 51005, 'Job surveyor identity not found.', 1;

    DECLARE
        @OldStatusGuid UNIQUEIDENTIFIER,
        @OldStatusId INT,
        @OldStatusName NVARCHAR(250);

    SELECT TOP (1)
        @OldStatusGuid = wfs.Guid,
        @OldStatusId = wfs.ID,
        @OldStatusName = wfs.Name
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs
      ON wfs.ID = dot.StatusID
     AND wfs.RowStatus NOT IN (0,254)
    WHERE dot.RowStatus NOT IN (0,254)
      AND dot.DataObjectGuid = @JobGuid
    ORDER BY dot.ID DESC;

    IF (@OldStatusGuid IS NULL)
        THROW 51006, 'No workflow history exists; cannot action closure.', 1;

    IF (@OldStatusGuid <> @Status_ClosureRequest)
        THROW 51007, 'Job is no longer in Closure Request state (latest status mismatch).', 1;

    IF (@Decision = 1 AND NULLIF(LTRIM(RTRIM(@Comment)), N'') IS NULL)
    BEGIN
        DECLARE @AuthoriserName NVARCHAR(250);
        SELECT @AuthoriserName = i.FullName
        FROM SCore.Identities i
        WHERE i.ID = @AuthoriserUserId
          AND i.RowStatus NOT IN (0,254);

        SET @Comment = CONCAT(N'Closure Approved by ', ISNULL(@AuthoriserName, CONCAT(N'UserId ', @AuthoriserUserId)));
    END

    SET @StoredComment = @Comment;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE
            @TransitionGuid UNIQUEIDENTIFIER,
            @IsImported BIT = 0,
            @DataObjectGuid UNIQUEIDENTIFIER = @JobGuid;

        DECLARE
            @NewStatusGuid UNIQUEIDENTIFIER,
            @NewStatusId INT,
            @NewStatusName NVARCHAR(250);

        IF (@Decision = 1)
        BEGIN
            /* 1) Approve Closure transition */
            SET @TransitionGuid = NEWID();

            EXECUTE @RC = [SCore].[DataObjectTransitionUpsert]
                   @TransitionGuid
                  ,@OldStatusGuid
                  ,@Status_ApproveClosure
                  ,@Comment
                  ,@CreatedByUserGuid
                  ,@SurveyorUserGuid
                  ,@DataObjectGuid
                  ,@IsImported;

            IF (@RC <> 0)
                THROW 51008, 'DataObjectTransitionUpsert failed for Approve Closure.', 1;

            /* 2) Completed transition */
            SET @TransitionGuid = NEWID();

            EXECUTE @RC = [SCore].[DataObjectTransitionUpsert]
                   @TransitionGuid
                  ,@Status_ApproveClosure
                  ,@Status_Completed
                  ,N'Completed as part of closure approval.'
                  ,@CreatedByUserGuid
                  ,@SurveyorUserGuid
                  ,@DataObjectGuid
                  ,@IsImported;

            IF (@RC <> 0)
                THROW 51009, 'DataObjectTransitionUpsert failed for Completed.', 1;

            SELECT
                @NewStatusGuid = ws.Guid,
                @NewStatusId = ws.ID,
                @NewStatusName = ws.Name
            FROM SCore.WorkflowStatus ws
            WHERE ws.Guid = @Status_Completed
              AND ws.RowStatus NOT IN (0,254);
        END
        ELSE
        BEGIN
            /* Reject transition */
            SET @TransitionGuid = NEWID();

            EXECUTE @RC = [SCore].[DataObjectTransitionUpsert]
                   @TransitionGuid
                  ,@OldStatusGuid
                  ,@Status_ClosureRejected
                  ,@Comment
                  ,@CreatedByUserGuid
                  ,@SurveyorUserGuid
                  ,@DataObjectGuid
                  ,@IsImported;

            IF (@RC <> 0)
                THROW 51010, 'DataObjectTransitionUpsert failed for Closure Rejected.', 1;

            SELECT
                @NewStatusGuid = ws.Guid,
                @NewStatusId = ws.ID,
                @NewStatusName = ws.Name
            FROM SCore.WorkflowStatus ws
            WHERE ws.Guid = @Status_ClosureRejected
              AND ws.RowStatus NOT IN (0,254);
        END

        /* Resolve job / actor / OU / workflow values for dedicated notification payload */
        DECLARE
            @OutboxGuid UNIQUEIDENTIFIER = NEWID(),
            @EventType NVARCHAR(200) = N'JobClosureDecision',
            @JobNumber NVARCHAR(100) = NULL,
            @JobTitle NVARCHAR(500) = NULL,
            @BillingInstruction NVARCHAR(500) = NULL,
            @OrganisationalUnitId INT = NULL,
            @OrganisationalUnitName NVARCHAR(250) = NULL,
            @WorkflowId INT = NULL,
            @WorkflowName NVARCHAR(250) = NULL,
            @ActorFullName NVARCHAR(250) = NULL,
            @ActorEmailAddress NVARCHAR(320) = NULL;

        SELECT
            @JobNumber = j.Number,
            @JobTitle = j.JobDescription,
            @BillingInstruction = j.BillingInstruction,
            @OrganisationalUnitId = j.OrganisationalUnitId
        FROM SJob.Jobs j
        WHERE j.Guid = @JobGuid
          AND j.RowStatus NOT IN (0,254);

        IF (@OrganisationalUnitId IS NOT NULL)
        BEGIN
            SELECT TOP (1)
                @OrganisationalUnitName = ou.Name
            FROM SCore.OrganisationalUnits ou
            WHERE ou.ID = @OrganisationalUnitId
              AND ou.RowStatus NOT IN (0,254);
        END

        SELECT
            @ActorFullName = i.FullName,
            @ActorEmailAddress = i.EmailAddress
        FROM SCore.Identities i
        WHERE i.ID = @AuthoriserUserId
          AND i.RowStatus NOT IN (0,254);

        /*
           Resolve workflow using the same pattern as
           SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification:
           - route by entity type + OU
           - match workflow by resulting status
           - prefer exact OU over OU = -1 fallback
        */
        DECLARE @EntityTypeId INT = NULL;

        SELECT TOP (1)
            @EntityTypeId = dob.EntityTypeId
        FROM SCore.DataObjects dob
        WHERE dob.Guid = @JobGuid
          AND dob.RowStatus NOT IN (0,254);

        IF (@EntityTypeId IS NOT NULL AND @NewStatusId IS NOT NULL)
        BEGIN
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
              AND wft.ToStatusID = @NewStatusId
            ORDER BY
                CASE WHEN wf.OrganisationalUnitId = @OrganisationalUnitId THEN 0 ELSE 1 END,
                wf.ID DESC;
        END

        /*
           Recipients
           ---------
           For now, align to the new dedicated-notification pattern:
           include recipients directly in payload JSON.

           This example uses the job surveyor and the acting authoriser when email exists.
           Extend here later if you want broader routing.
        */
        DECLARE @RecipientsJson NVARCHAR(MAX);

        ;WITH Recipients AS
        (
            SELECT DISTINCT EmailAddress
            FROM
            (
                SELECT ai.EmailAddress
                FROM SCore.Identities ai
                WHERE ai.ID = @AuthoriserUserId
                  AND ai.RowStatus NOT IN (0,254)

                UNION ALL

                SELECT si.EmailAddress
                FROM SJob.Jobs j
                JOIN SCore.Identities si
                  ON si.ID = j.SurveyorID
                 AND si.RowStatus NOT IN (0,254)
                WHERE j.Guid = @JobGuid
                  AND j.RowStatus NOT IN (0,254)
            ) x
            WHERE x.EmailAddress IS NOT NULL
              AND LTRIM(RTRIM(x.EmailAddress)) <> N''
        )
        SELECT @RecipientsJson =
        (
            SELECT r.EmailAddress
            FROM Recipients r
            FOR JSON PATH
        );

        IF (@RecipientsJson IS NULL OR @RecipientsJson = N'')
            SET @RecipientsJson = N'[]';

        DECLARE @Payload NVARCHAR(MAX);

        SET @Payload =
        (
            SELECT
                @OutboxGuid AS eventGuid,
                @EventType AS eventType,
                @NowUtc AS occurredOnUtc,

                @JobGuid AS dataObjectGuid,
                @JobGuid AS jobGuid,
                @JobNumber AS jobNumber,
                @JobTitle AS jobTitle,
                @BillingInstruction AS description,

                @OrganisationalUnitId AS organisationalUnitId,
                @OrganisationalUnitName AS organisationalUnitName,

                @WorkflowId AS workflowId,
                @WorkflowName AS workflowName,

                @NewStatusId AS statusId,
                @NewStatusGuid AS statusGuid,
                @NewStatusName AS statusName,

                @OldStatusId AS oldStatusId,
                @OldStatusGuid AS oldStatusGuid,
                @OldStatusName AS oldStatusName,

                @StoredComment AS comment,

                JSON_QUERY
                (
                    (
                        SELECT
                            @AuthoriserUserId AS identityId,
                            @ActorFullName AS fullName,
                            @ActorEmailAddress AS emailAddress
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    )
                ) AS actor,

                JSON_QUERY(@RecipientsJson) AS recipients
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        INSERT INTO SCore.IntegrationOutbox
        (
            Guid,
            EventType,
            PayloadJson
        )
        VALUES
        (
            @OutboxGuid,
            @EventType,
            @Payload
        );

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH
END
GO