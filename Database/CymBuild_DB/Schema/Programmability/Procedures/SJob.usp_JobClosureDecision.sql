SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

/* =============================================================================
   Proc: SJob.usp_JobClosureDecision
   - Hard gate: latest workflow status MUST be Closure Request
   - Approve:
       * optional comment; default "Closure Approved by {USER}"
       * add Approve Closure transition
       * add Completed transition
       * update legacy completion fields (read-only behavior)
   - Reject:
       * comment mandatory
       * add Closure Rejected transition
       * do NOT complete
   - Writes outbox record for Kafka publishing later (out-of-scope)
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

    IF NOT EXISTS (SELECT 1 FROM SJob.Jobs WHERE Guid = @JobGuid AND RowStatus NOT IN (0,254))
        THROW 51003, 'Job not found (or invalid RowStatus).', 1;

    -- Resolve identity GUID for authoriser
    DECLARE @CreatedByUserGuid UNIQUEIDENTIFIER;
    SELECT @CreatedByUserGuid = i.Guid
    FROM SCore.Identities i
    WHERE i.ID = @AuthoriserUserId;

    IF (@CreatedByUserGuid IS NULL)
        THROW 51004, 'Authoriser identity not found.', 1;

    -- Resolve surveyor identity GUID from job
    DECLARE @SurveyorUserGuid UNIQUEIDENTIFIER;
    SELECT @SurveyorUserGuid = si.Guid
    FROM SJob.Jobs j
    JOIN SCore.Identities si ON si.ID = j.SurveyorID
    WHERE j.Guid = @JobGuid;

    IF (@SurveyorUserGuid IS NULL)
        THROW 51005, 'Job surveyor identity not found.', 1;

    -- Latest workflow status = OldStatusGuid (must be Closure Request)
    DECLARE @OldStatusGuid UNIQUEIDENTIFIER;

    SELECT TOP (1)
        @OldStatusGuid = wfs.Guid
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.RowStatus NOT IN (0,254)
      AND dot.DataObjectGuid = @JobGuid
    ORDER BY dot.ID DESC;

    IF (@OldStatusGuid IS NULL)
        THROW 51006, 'No workflow history exists; cannot action closure.', 1;

    IF (@OldStatusGuid <> @Status_ClosureRequest)
        THROW 51007, 'Job is no longer in Closure Request state (latest status mismatch).', 1;

    -- Default approval comment if empty
    IF (@Decision = 1 AND NULLIF(LTRIM(RTRIM(@Comment)), N'') IS NULL)
    BEGIN
        DECLARE @AuthoriserName NVARCHAR(250);
        SELECT @AuthoriserName = FullName FROM SCore.Identities WHERE ID = @AuthoriserUserId;

        SET @Comment = CONCAT(N'Closure Approved by ', ISNULL(@AuthoriserName, CONCAT(N'UserId ', @AuthoriserUserId)));
    END

    SET @StoredComment = @Comment;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE
            @TransitionGuid UNIQUEIDENTIFIER,
            @IsImported BIT = 0,
            @DataObjectGuid UNIQUEIDENTIFIER = @JobGuid;

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

            --/* 3) Legacy completion fields to enforce read-only behavior */
            --UPDATE j
            --SET
            --    j.IsComplete = 1,
            --    j.JobCompleted = @NowUtc,
            --    j.IsCompleteForReview = 0
            --FROM SJob.Jobs j
            --WHERE j.Guid = @JobGuid;
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
        END

        /* Outbox record (Kafka-ready; worker will publish later) */
        DECLARE
            @OutboxGuid UNIQUEIDENTIFIER = NEWID(),
            @EventType NVARCHAR(200) = N'JobClosureDecision',
            @TargetGroupCode NVARCHAR(100) = N'AUTHORISER_CLOSURE_NOTIFICATIONS',
            @TargetUserGroupGuid UNIQUEIDENTIFIER = NULL; -- optional

        DECLARE @Payload NVARCHAR(MAX) =
        (
            SELECT
                @JobGuid AS JobGuid,
                @Decision AS DecisionCode,
                CASE WHEN @Decision = 1 THEN N'Approve' ELSE N'Reject' END AS Decision,
                @StoredComment AS Comment,
                @CreatedByUserGuid AS ActorUserGuid,
                @AuthoriserUserId AS ActorUserId,
                @NowUtc AS DecisionDateTimeUtc,
                @TargetGroupCode AS TargetGroupCode,
                @TargetUserGroupGuid AS TargetUserGroupGuid
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        INSERT INTO SCore.IntegrationOutbox(Guid, EventType, PayloadJson)
        VALUES (@OutboxGuid, @EventType, @Payload);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO