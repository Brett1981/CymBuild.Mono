SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionSageSubmission_EnsureQueued]')
GO
PRINT (N'Create procedure [SFin].[TransactionSageSubmission_EnsureQueued]')
GO
CREATE PROCEDURE [SFin].[TransactionSageSubmission_EnsureQueued]
(
      @TransactionID       BIGINT = NULL
    , @TransactionGuid     UNIQUEIDENTIFIER = NULL
    , @CreatedByUserId     INT = -1
    , @SurveyorUserId      INT = -1
    , @Comment             NVARCHAR(MAX) = NULL
    , @SuppressResult      BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @ResolvedTransactionID BIGINT
        , @ResolvedTransactionGuid UNIQUEIDENTIFIER
        , @SourceTransactionRowVersion BINARY(8)
        , @BeforeMaxTransitionID BIGINT
        , @TransitionID BIGINT
        , @TransitionGuid UNIQUEIDENTIFIER
        , @OutboxID BIGINT
        , @Outcome NVARCHAR(50) = N''
        , @Message NVARCHAR(MAX) = N'';

    IF @TransactionID IS NULL AND @TransactionGuid IS NULL
        THROW 60200, 'TransactionSageSubmission_EnsureQueued requires TransactionID or TransactionGuid.', 1;

    BEGIN TRY
        BEGIN TRAN;

        SELECT TOP (1)
              @ResolvedTransactionID = t.ID
            , @ResolvedTransactionGuid = t.Guid
            , @SourceTransactionRowVersion = t.RowVersion
        FROM SFin.Transactions AS t WITH (UPDLOCK, HOLDLOCK)
        WHERE t.RowStatus <> 0
          AND t.RowStatus <> 254
          AND (@TransactionID IS NULL OR t.ID = @TransactionID)
          AND (@TransactionGuid IS NULL OR t.Guid = @TransactionGuid)
        ORDER BY t.ID DESC;

        IF @ResolvedTransactionID IS NULL
            THROW 60201, 'TransactionSageSubmission_EnsureQueued could not resolve an active transaction.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM SFin.Transactions AS t
            WHERE t.ID = @ResolvedTransactionID
              AND t.Guid = @ResolvedTransactionGuid
              AND t.RowStatus <> 0
              AND t.RowStatus <> 254
              AND ISNULL(t.Batched, 1) <> 0
        )
        BEGIN
            SET @Outcome = N'NotApproved';
            SET @Message = N'Transaction is still batched; Sage submission was not queued.';
            COMMIT TRAN;

            IF ISNULL(@SuppressResult, 0) = 0
            BEGIN
                SELECT TransactionID = @ResolvedTransactionID, TransactionGuid = @ResolvedTransactionGuid,
                       TransitionID = @TransitionID, TransitionGuid = @TransitionGuid, OutboxID = @OutboxID,
                       Outcome = @Outcome, [Message] = @Message;
            END;

            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM SFin.Transactions AS t WITH (UPDLOCK, HOLDLOCK)
            LEFT JOIN SFin.TransactionSageSubmissionStatus AS s WITH (UPDLOCK, HOLDLOCK)
                ON s.TransactionGuid = t.Guid
               AND s.RowStatus <> 0
               AND s.RowStatus <> 254
            WHERE t.ID = @ResolvedTransactionID
              AND t.Guid = @ResolvedTransactionGuid
              AND t.RowStatus <> 0
              AND t.RowStatus <> 254
              AND
              (
                    s.StatusCode = N'Succeeded'
                 OR s.LastSucceededOnUtc IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(ISNULL(s.SageOrderId, N''))), N'') IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(ISNULL(s.SageOrderNumber, N''))), N'') IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(ISNULL(t.SageTransactionReference, N''))), N'') IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(ISNULL(t.SageInvoiceNumber, N''))), N'') IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(ISNULL(t.SageSalesOrderNumber, N''))), N'') IS NOT NULL
              )
        )
        BEGIN
            SET @Outcome = N'AlreadySucceeded';
            SET @Message = N'Transaction already has Sage success/reference values; Sage submission was not queued again.';
            COMMIT TRAN;

            IF ISNULL(@SuppressResult, 0) = 0
            BEGIN
                SELECT TransactionID = @ResolvedTransactionID, TransactionGuid = @ResolvedTransactionGuid,
                       TransitionID = @TransitionID, TransitionGuid = @TransitionGuid, OutboxID = @OutboxID,
                       Outcome = @Outcome, [Message] = @Message;
            END;

            RETURN;
        END;

        SELECT TOP (1)
              @OutboxID = io.ID
        FROM SCore.IntegrationOutbox AS io WITH (UPDLOCK, HOLDLOCK)
        WHERE io.RowStatus <> 0
          AND io.RowStatus <> 254
          AND io.EventType = N'TransactionApprovedForSageSubmission'
          AND io.PublishedOnUtc IS NULL
          AND ISJSON(io.PayloadJson) = 1
          AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(CASE WHEN ISJSON(io.PayloadJson) = 1 THEN io.PayloadJson ELSE N'{}' END, '$.transactionGuid')) = @ResolvedTransactionGuid
        ORDER BY io.ID DESC;

        IF @OutboxID IS NOT NULL
        BEGIN
            EXEC SFin.TransactionSageSubmissionStatus_Ensure
                 @TransactionID = @ResolvedTransactionID,
                 @TransactionGuid = @ResolvedTransactionGuid,
                 @TransitionGuid = NULL,
                 @CreatedByUserID = @CreatedByUserId;

            SET @Outcome = N'AlreadyQueued';
            SET @Message = N'An active unpublished Sage submission outbox event already exists.';
            COMMIT TRAN;

            IF ISNULL(@SuppressResult, 0) = 0
            BEGIN
                SELECT TransactionID = @ResolvedTransactionID, TransactionGuid = @ResolvedTransactionGuid,
                       TransitionID = @TransitionID, TransitionGuid = @TransitionGuid, OutboxID = @OutboxID,
                       Outcome = @Outcome, [Message] = @Message;
            END;

            RETURN;
        END;

        SELECT TOP (1)
              @TransitionID = tbt.ID
            , @TransitionGuid = tbt.Guid
        FROM SFin.TransactionBatchTransitions AS tbt WITH (UPDLOCK, HOLDLOCK)
        WHERE tbt.TransactionID = @ResolvedTransactionID
          AND tbt.TransactionGuid = @ResolvedTransactionGuid
          AND tbt.RowStatus <> 0
          AND tbt.RowStatus <> 254
          AND ISNULL(tbt.OldBatched, 0) = 1
          AND ISNULL(tbt.NewBatched, 1) = 0
        ORDER BY
            CASE WHEN tbt.SourceTransactionRowVersion = @SourceTransactionRowVersion THEN 0 ELSE 1 END,
            tbt.ID DESC;

        IF @TransitionID IS NULL
        BEGIN
            SELECT @BeforeMaxTransitionID = ISNULL(MAX(tbt.ID), 0)
            FROM SFin.TransactionBatchTransitions AS tbt
            WHERE tbt.TransactionID = @ResolvedTransactionID
              AND tbt.TransactionGuid = @ResolvedTransactionGuid;

            EXEC SFin.TransactionBatchTransition_Insert
                 @TransactionID = @ResolvedTransactionID,
                 @TransactionGuid = @ResolvedTransactionGuid,
                 @OldBatched = 1,
                 @NewBatched = 0,
                 @CreatedByUserId = @CreatedByUserId,
                 @SurveyorUserId = @SurveyorUserId,
                 @Comment = @Comment,
                 @IsImported = 0,
                 @SourceTransactionRowVersion = @SourceTransactionRowVersion;

            SELECT TOP (1)
                  @TransitionID = tbt.ID
                , @TransitionGuid = tbt.Guid
            FROM SFin.TransactionBatchTransitions AS tbt
            WHERE tbt.TransactionID = @ResolvedTransactionID
              AND tbt.TransactionGuid = @ResolvedTransactionGuid
              AND tbt.ID > @BeforeMaxTransitionID
              AND tbt.RowStatus <> 0
              AND tbt.RowStatus <> 254
            ORDER BY tbt.ID DESC;
        END;

        IF @TransitionID IS NULL
        BEGIN
            SELECT TOP (1)
                  @TransitionID = tbt.ID
                , @TransitionGuid = tbt.Guid
            FROM SFin.TransactionBatchTransitions AS tbt
            WHERE tbt.TransactionID = @ResolvedTransactionID
              AND tbt.TransactionGuid = @ResolvedTransactionGuid
              AND tbt.RowStatus <> 0
              AND tbt.RowStatus <> 254
              AND ISNULL(tbt.OldBatched, 0) = 1
              AND ISNULL(tbt.NewBatched, 1) = 0
            ORDER BY tbt.ID DESC;
        END;

        IF @TransitionID IS NULL OR @TransitionGuid IS NULL
            THROW 60202, 'TransactionSageSubmission_EnsureQueued could not create or resolve a transaction batch transition.', 1;

        EXEC SFin.TransactionSageSubmissionStatus_Ensure
             @TransactionID = @ResolvedTransactionID,
             @TransactionGuid = @ResolvedTransactionGuid,
             @TransitionGuid = @TransitionGuid,
             @CreatedByUserID = @CreatedByUserId;

        IF NOT EXISTS
        (
            SELECT 1
            FROM SCore.IntegrationOutbox AS io WITH (UPDLOCK, HOLDLOCK)
            WHERE io.RowStatus <> 0
              AND io.RowStatus <> 254
              AND io.EventType = N'TransactionApprovedForSageSubmission'
              AND io.PublishedOnUtc IS NULL
              AND ISJSON(io.PayloadJson) = 1
              AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(CASE WHEN ISJSON(io.PayloadJson) = 1 THEN io.PayloadJson ELSE N'{}' END, '$.transactionGuid')) = @ResolvedTransactionGuid
        )
        BEGIN
            EXEC SFin.TransactionBatchTransition_EnqueueOutbox
                 @TransactionBatchTransitionGuid = @TransitionGuid;
        END;

        SELECT TOP (1)
              @OutboxID = io.ID
        FROM SCore.IntegrationOutbox AS io
        WHERE io.RowStatus <> 0
          AND io.RowStatus <> 254
          AND io.EventType = N'TransactionApprovedForSageSubmission'
          AND io.PublishedOnUtc IS NULL
          AND ISJSON(io.PayloadJson) = 1
          AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(CASE WHEN ISJSON(io.PayloadJson) = 1 THEN io.PayloadJson ELSE N'{}' END, '$.transactionGuid')) = @ResolvedTransactionGuid
        ORDER BY io.ID DESC;

        IF @OutboxID IS NULL
            THROW 60203, 'TransactionSageSubmission_EnsureQueued resolved a transition but no active unpublished outbox event exists after enqueue.', 1;

        SET @Outcome = N'Queued';
        SET @Message = N'Sage submission outbox event is queued.';

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        THROW;
    END CATCH;

    IF ISNULL(@SuppressResult, 0) = 0
    BEGIN
        SELECT
              TransactionID = @ResolvedTransactionID
            , TransactionGuid = @ResolvedTransactionGuid
            , TransitionID = @TransitionID
            , TransitionGuid = @TransitionGuid
            , OutboxID = @OutboxID
            , Outcome = @Outcome
            , [Message] = @Message;
    END;
END
GO