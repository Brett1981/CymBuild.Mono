SET XACT_ABORT ON
GO

PRINT N'CYB Sage posting reliability patch for 26.3'
GO


PRINT N'Applying SFin.TransactionSageSubmission_EnsureQueued.sql'
GO
CREATE OR ALTER PROCEDURE [SFin].[TransactionSageSubmission_EnsureQueued]
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
          AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transactionGuid')) = @ResolvedTransactionGuid
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
              AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transactionGuid')) = @ResolvedTransactionGuid
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
          AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transactionGuid')) = @ResolvedTransactionGuid
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
GO


PRINT N'Applying SFin.TransactionSageSubmission_Requeue.sql'
GO
CREATE OR ALTER PROCEDURE [SFin].[TransactionSageSubmission_Requeue]
(
    @TransactionGuid              UNIQUEIDENTIFIER = NULL,
    @TransactionGuidsJson         NVARCHAR(MAX) = NULL,
    @IncludeNonRetryableFailures  BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserID INT = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

    IF (@TransactionGuid IS NULL)
       AND (NULLIF(LTRIM(RTRIM(@TransactionGuidsJson)), N'') IS NULL)
        THROW 50001, 'Either @TransactionGuid or @TransactionGuidsJson must be supplied.', 1;

    IF (@TransactionGuid IS NOT NULL)
       AND (NULLIF(LTRIM(RTRIM(@TransactionGuidsJson)), N'') IS NOT NULL)
        THROW 50002, 'Provide either @TransactionGuid or @TransactionGuidsJson, not both.', 1;

    IF (@TransactionGuidsJson IS NOT NULL AND ISJSON(@TransactionGuidsJson) <> 1)
        THROW 50003, '@TransactionGuidsJson must be a valid JSON array.', 1;

    DECLARE @RequestedGuids TABLE
    (
        TransactionGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
    );

    IF (@TransactionGuid IS NOT NULL)
    BEGIN
        INSERT INTO @RequestedGuids (TransactionGuid)
        VALUES (@TransactionGuid);
    END
    ELSE
    BEGIN
        INSERT INTO @RequestedGuids (TransactionGuid)
        SELECT DISTINCT TRY_CONVERT(UNIQUEIDENTIFIER, j.[value])
        FROM OPENJSON(@TransactionGuidsJson) AS j
        WHERE TRY_CONVERT(UNIQUEIDENTIFIER, j.[value]) IS NOT NULL;
    END;

    IF NOT EXISTS (SELECT 1 FROM @RequestedGuids)
        THROW 50004, 'No valid transaction guids were supplied.', 1;

    DECLARE @Targets TABLE
    (
        TransactionID BIGINT NOT NULL,
        TransactionGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        StatusID BIGINT NULL,
        CurrentStatusCode NVARCHAR(30) NULL,
        LastErrorIsRetryable BIT NULL
    );

    INSERT INTO @Targets
    (
        TransactionID,
        TransactionGuid,
        StatusID,
        CurrentStatusCode,
        LastErrorIsRetryable
    )
    SELECT
        t.ID,
        t.Guid,
        s.ID,
        s.StatusCode,
        s.LastErrorIsRetryable
    FROM SFin.Transactions AS t
    INNER JOIN @RequestedGuids AS rg
        ON rg.TransactionGuid = t.Guid
    LEFT JOIN SFin.TransactionSageSubmissionStatus AS s
        ON s.TransactionGuid = t.Guid
       AND s.RowStatus NOT IN (0, 254)
    WHERE t.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(t.Guid, @UserID) AS oscr
      );

    IF NOT EXISTS (SELECT 1 FROM @Targets)
    BEGIN
        SELECT
            CAST(0 AS INT) AS RequeuedTransactionCount,
            CAST(0 AS INT) AS ResetOutboxRowCount,
            CAST(0 AS INT) AS ResetStatusRowCount,
            N'No accessible transactions were found for the supplied guid(s).' AS [Message];

        RETURN;
    END;

    DECLARE @ResetCandidates TABLE
    (
        TransactionID BIGINT NOT NULL,
        TransactionGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        StatusID BIGINT NULL
    );

    INSERT INTO @ResetCandidates
    (
        TransactionID,
        TransactionGuid,
        StatusID
    )
    SELECT
        x.TransactionID,
        x.TransactionGuid,
        x.StatusID
    FROM @Targets AS x
    WHERE ISNULL(x.CurrentStatusCode, N'') <> N'Succeeded'
      AND
      (
            x.StatusID IS NULL
         OR x.CurrentStatusCode IS NULL
         OR x.CurrentStatusCode IN (N'Pending', N'InProgress', N'FailedRetryable')
         OR (ISNULL(x.LastErrorIsRetryable, 0) = 1)
         OR (@IncludeNonRetryableFailures = 1 AND x.CurrentStatusCode = N'FailedNonRetryable')
      );

    IF NOT EXISTS (SELECT 1 FROM @ResetCandidates)
    BEGIN
        SELECT
            CAST(0 AS INT) AS RequeuedTransactionCount,
            CAST(0 AS INT) AS ResetOutboxRowCount,
            CAST(0 AS INT) AS ResetStatusRowCount,
            CASE
                WHEN @IncludeNonRetryableFailures = 1
                    THEN N'No eligible transaction submissions were found to reset.'
                ELSE N'No eligible retryable transaction submissions were found to reset.'
            END AS [Message];

        SELECT
            t.TransactionID,
            t.TransactionGuid,
            t.StatusID,
            t.CurrentStatusCode,
            t.LastErrorIsRetryable
        FROM @Targets AS t
        ORDER BY t.TransactionID;

        RETURN;
    END;

    DECLARE @ResetOutbox TABLE (ID BIGINT NOT NULL PRIMARY KEY);
    DECLARE @ResetStatuses TABLE (ID BIGINT NOT NULL PRIMARY KEY);

    BEGIN TRAN;

    UPDATE io
    SET
        io.PublishAttempts = 0,
        io.PublishingStartedOnUtc = NULL,
        io.PublishingToken = NULL,
        io.PublishedOnUtc = NULL,
        io.LastError = NULL
    OUTPUT inserted.ID INTO @ResetOutbox(ID)
    FROM SCore.IntegrationOutbox AS io
    INNER JOIN @ResetCandidates AS rc
        ON TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transactionGuid')) = rc.TransactionGuid
    WHERE io.RowStatus NOT IN (0, 254)
      AND io.EventType = N'TransactionApprovedForSageSubmission';

    UPDATE s
    SET
        s.StatusCode = N'Pending',
        s.IsInProgress = 0,
        s.InProgressClaimedOnUtc = NULL,
        s.LastFailedOnUtc = NULL,
        s.LastError = NULL,
        s.LastErrorIsRetryable = NULL,
        s.UpdatedDateTimeUTC = SYSUTCDATETIME(),
        s.UpdatedByUserID = @UserID
    OUTPUT inserted.ID INTO @ResetStatuses(ID)
    FROM SFin.TransactionSageSubmissionStatus AS s
    INNER JOIN @ResetCandidates AS rc
        ON rc.StatusID = s.ID
    WHERE s.RowStatus NOT IN (0, 254)
      AND ISNULL(s.StatusCode, N'') <> N'Succeeded';

    COMMIT TRAN;

    DECLARE
        @EnsureTransactionID BIGINT,
        @EnsureTransactionGuid UNIQUEIDENTIFIER;

    DECLARE ensure_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            rc.TransactionID,
            rc.TransactionGuid
        FROM @ResetCandidates AS rc
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SCore.IntegrationOutbox AS io
            WHERE io.RowStatus <> 0
              AND io.RowStatus <> 254
              AND io.EventType = N'TransactionApprovedForSageSubmission'
              AND io.PublishedOnUtc IS NULL
              AND ISJSON(io.PayloadJson) = 1
              AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transactionGuid')) = rc.TransactionGuid
        );

    OPEN ensure_cur;

    FETCH NEXT FROM ensure_cur INTO @EnsureTransactionID, @EnsureTransactionGuid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SFin.TransactionSageSubmission_EnsureQueued
             @TransactionID = @EnsureTransactionID,
             @TransactionGuid = @EnsureTransactionGuid,
             @CreatedByUserId = @UserID,
             @SurveyorUserId = -1,
             @Comment = N'Sage submission requeue ensured missing outbox event.',
             @SuppressResult = 1;

        FETCH NEXT FROM ensure_cur INTO @EnsureTransactionID, @EnsureTransactionGuid;
    END;

    CLOSE ensure_cur;
    DEALLOCATE ensure_cur;

    SELECT
        COUNT(*) AS RequeuedTransactionCount,
        (SELECT COUNT(*) FROM @ResetOutbox) AS ResetOutboxRowCount,
        (SELECT COUNT(*) FROM @ResetStatuses) AS ResetStatusRowCount,
        CASE
            WHEN @IncludeNonRetryableFailures = 1
                THEN N'Transaction Sage submission reset for retry successfully.'
            ELSE N'Transaction Sage submission retry state reset successfully.'
        END AS [Message]
    FROM @ResetCandidates;

    SELECT
        rc.TransactionID,
        rc.TransactionGuid,
        ResetStatusRow = CASE WHEN rs.ID IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END,
        ResetOutboxRows =
        (
            SELECT COUNT(*)
            FROM SCore.IntegrationOutbox AS io
            WHERE io.RowStatus NOT IN (0, 254)
              AND io.EventType = N'TransactionApprovedForSageSubmission'
              AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transactionGuid')) = rc.TransactionGuid
              AND io.PublishAttempts = 0
              AND io.PublishingStartedOnUtc IS NULL
              AND io.PublishingToken IS NULL
              AND io.LastError IS NULL
        )
    FROM @ResetCandidates AS rc
    LEFT JOIN @ResetStatuses AS rs
        ON rs.ID = rc.StatusID
    ORDER BY rc.TransactionID;
END;
GO
GO


PRINT N'Applying SFin.TransactionUnbatch.sql'
GO
CREATE OR ALTER PROCEDURE [SFin].[TransactionUnbatch]
    @Guid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @IsBatched BIT = 0,
        @TransactionID BIGINT,
        @TransactionNumber NVARCHAR(30),
        @SurveyorUserId INT,
        @CreatedByUserId INT;

    DECLARE @EnsureOutcome TABLE
    (
        TransactionID BIGINT NULL,
        TransactionGuid UNIQUEIDENTIFIER NULL,
        TransitionID BIGINT NULL,
        TransitionGuid UNIQUEIDENTIFIER NULL,
        OutboxID BIGINT NULL,
        Outcome NVARCHAR(50) NULL,
        [Message] NVARCHAR(MAX) NULL
    );

    SELECT
        @TransactionID = ID,
        @IsBatched = Batched,
        @TransactionNumber = Number,
        @SurveyorUserId = SurveyorUserId,
        @CreatedByUserId = CreatedByUserId
    FROM SFin.Transactions
    WHERE Guid = @Guid
      AND RowStatus <> 0
      AND RowStatus <> 254;

    IF @TransactionID IS NULL
    BEGIN
        ;THROW 51002, 'Cannot unbatch transaction because it was not found or is inactive.', 1;
    END;

    IF (@IsBatched = 1)
    BEGIN
        UPDATE SFin.Transactions
        SET Batched = 0
        WHERE Guid = @Guid
          AND RowStatus <> 0
          AND RowStatus <> 254;
    END;

    /*
        CYB-414 / Sage posting reliability
        -------------------------------
        Always ensure the Sage submission event is queued after this procedure is
        called, even if the transaction is already Batched = 0. This makes the
        Post to Sage action idempotent and repairs the partial Live state where
        the transaction had been unbatched but no TransactionBatchTransition /
        TransactionApprovedForSageSubmission outbox row existed.
    */
    INSERT INTO @EnsureOutcome
    EXEC SFin.TransactionSageSubmission_EnsureQueued
         @TransactionID = @TransactionID,
         @TransactionGuid = @Guid,
         @CreatedByUserId = @CreatedByUserId,
         @SurveyorUserId = @SurveyorUserId,
         @Comment = N'Finance approval detected from TransactionUnbatch.',
         @SuppressResult = 0;

    SELECT
        TransactionID,
        TransactionGuid,
        TransitionID,
        TransitionGuid,
        OutboxID,
        Outcome,
        [Message]
    FROM @EnsureOutcome;
END;
GO
GO


PRINT N'Applying SFin.TransactionsUpsert.sql'
GO
CREATE OR ALTER PROCEDURE [SFin].[TransactionsUpsert]
(
    @AccountGuid UNIQUEIDENTIFIER,
    @JobGuid UNIQUEIDENTIFIER,
    @TransactionTypeGuid UNIQUEIDENTIFIER,
    @Date DATE,
    @PurchaseOrderNumber NVARCHAR(28),
    @SageTransactionReference NVARCHAR(50),
    @OrganisationalUnitGuid UNIQUEIDENTIFIER,
    @CreatedByUserGuid UNIQUEIDENTIFIER,
    @SurveyorGuid UNIQUEIDENTIFIER,
    @CreditTermsGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER,
    @Batched BIT,
	@ExpectedDate DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccountID INT,
            @JobID INT,
            @TransactionTypeId SMALLINT,
            @IsInsert BIT = 0,
            @TranNo INT,
            @OrganisationalUnitId INT,
            @DepartmentPrefix NVARCHAR(10),
            @CreatedByUserId INT,
            @SurveyorUserId INT,
            @CreditTermsId INT,
            @ExistingBatched BIT,
            @ExistingAccountID INT,
            @ExistingJobID INT,
            @TransactionID BIGINT,
            @EnsureQueuedComment NVARCHAR(MAX);

    SELECT  @AccountID = ID
    FROM    SCrm.Accounts
    WHERE   [Guid] = @AccountGuid;

    SELECT  @JobID = ID
    FROM    SJob.Jobs
    WHERE   [Guid] = @JobGuid;

    SELECT  @TransactionTypeId = ID
    FROM    SFin.TransactionTypes
    WHERE   [Guid] = @TransactionTypeGuid;

    SELECT  @CreatedByUserId = ID
    FROM    SCore.Identities
    WHERE   [Guid] = @CreatedByUserGuid;

    SELECT  @SurveyorUserId = ID
    FROM    SCore.Identities
    WHERE   [Guid] = @SurveyorGuid;

    SELECT  @CreditTermsId = ID
    FROM    SFin.CreditTerms
    WHERE   [Guid] = @CreditTermsGuid;

    SELECT  @OrganisationalUnitId = ID,
            @DepartmentPrefix = DepartmentPrefix
    FROM    SCore.OrganisationalUnits ou
    WHERE   ou.Guid = @OrganisationalUnitGuid;

    EXEC SCore.UpsertDataObject
         @Guid = @Guid,
         @SchemeName = N'SFin',
         @ObjectName = N'Transactions',
         @IsInsert = @IsInsert OUTPUT;

    IF (@IsInsert = 1)
    BEGIN
        INSERT SFin.Transactions
        (
            RowStatus,
            Guid,
            TransactionTypeID,
            AccountID,
            JobID,
            Number,
            Date,
            PurchaseOrderNumber,
            SageTransactionReference,
            OrganisationalUnitId,
            CreatedByUserId,
            SurveyorUserId,
            CreditTermsId,
            Batched,
			ExpectedDate
        )
        VALUES
        (
            0,
            @Guid,
            @TransactionTypeId,
            @AccountID,
            @JobID,
            0,
            @Date,
            @PurchaseOrderNumber,
            @SageTransactionReference,
            @OrganisationalUnitId,
            @CreatedByUserId,
            @SurveyorUserId,
            @CreditTermsId,
            1,
			@ExpectedDate
        );
    END
    ELSE
    BEGIN
        SELECT  @TransactionID = t.ID,
                @ExistingBatched = t.Batched,
                @ExistingAccountID = t.AccountID,
                @ExistingJobID = t.JobID
        FROM    SFin.Transactions t
        WHERE   t.Guid = @Guid;

        UPDATE  SFin.Transactions
        SET     Date = @Date,
                JobID = @JobID,
                PurchaseOrderNumber = @PurchaseOrderNumber,
                SageTransactionReference = @SageTransactionReference,
                SurveyorUserId = @SurveyorUserId,
                CreditTermsId = @CreditTermsId,
                Batched = @Batched,
				ExpectedDate = @ExpectedDate,
                AccountID = CASE
                                WHEN @ExistingBatched = 1 THEN @AccountID
                                ELSE AccountID
                            END
        WHERE   [Guid] = @Guid;

        IF (@ExistingBatched = 1 AND ISNULL(@ExistingAccountID, -1) <> ISNULL(@AccountID, -1))
        BEGIN
            UPDATE  SJob.Jobs
            SET     FinanceAccountID = @AccountID
            WHERE   ID = @ExistingJobID;
        END

        IF (ISNULL(@Batched, 1) = 0)
        BEGIN
            SET @EnsureQueuedComment =
                CASE
                    WHEN ISNULL(@ExistingBatched, 0) = 1
                        THEN N'Finance approval detected from TransactionsUpsert Batched 1 to 0.'
                    ELSE N'Finance approval repair detected from TransactionsUpsert for already unbatched transaction.'
                END;

            EXEC SFin.TransactionSageSubmission_EnsureQueued
                 @TransactionID = @TransactionID,
                 @TransactionGuid = @Guid,
                 @CreatedByUserId = @CreatedByUserId,
                 @SurveyorUserId = @SurveyorUserId,
                 @Comment = @EnsureQueuedComment,
                 @SuppressResult = 1;
        END
    END

    IF (@IsInsert = 1)
    BEGIN
        SELECT @TranNo = NEXT VALUE FOR SFin.TransactionNumber;

        UPDATE  SFin.Transactions
        SET     Number = @DepartmentPrefix + CONVERT(NVARCHAR(30), @TranNo),
                RowStatus = 1
        WHERE   [Guid] = @Guid;
    END
END
GO
GO


PRINT N'Applying [SFin].[tr_Transactions_RecordBatchApprovalTransition]'
GO
PRINT (N'Create trigger [SFin].[tr_Transactions_RecordBatchApprovalTransition] on table [SFin].[Transactions]')
GO
CREATE OR ALTER TRIGGER [SFin].[tr_Transactions_RecordBatchApprovalTransition]
ON [SFin].[Transactions]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF (ISNULL(CONVERT(INT, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
        RETURN;

    IF NOT UPDATE(Batched)
        RETURN;

    DECLARE
        @TransactionID BIGINT,
        @TransactionGuid UNIQUEIDENTIFIER,
        @SurveyorUserId INT,
        @CreatedByUserId INT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            i.ID,
            i.Guid,
            i.SurveyorUserId,
            COALESCE(CONVERT(INT, SESSION_CONTEXT(N'user_id')), i.CreatedByUserId, -1) AS CreatedByUserId
        FROM inserted AS i
        INNER JOIN deleted AS d
            ON d.ID = i.ID
        WHERE i.RowStatus <> 0
          AND i.RowStatus <> 254
          AND d.RowStatus <> 0
          AND d.RowStatus <> 254
          AND ISNULL(d.Batched, 0) = 1
          AND ISNULL(i.Batched, 0) = 0;

    OPEN cur;

    FETCH NEXT FROM cur INTO
        @TransactionID,
        @TransactionGuid,
        @SurveyorUserId,
        @CreatedByUserId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SFin.TransactionSageSubmission_EnsureQueued
             @TransactionID = @TransactionID,
             @TransactionGuid = @TransactionGuid,
             @CreatedByUserId = @CreatedByUserId,
             @SurveyorUserId = @SurveyorUserId,
             @Comment = N'Finance approval detected from Batched 1 to 0.',
             @SuppressResult = 1;

        FETCH NEXT FROM cur INTO
            @TransactionID,
            @TransactionGuid,
            @SurveyorUserId,
            @CreatedByUserId;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO


PRINT N'CYB Sage posting reliability patch applied. Use the result set below to check for already-unbatched transactions with no successful Sage submission and no active outbox event.'
GO

SELECT TOP (100)
    t.ID,
    t.Guid,
    t.Number,
    t.Batched,
    s.StatusCode,
    s.SageOrderNumber,
    t.SageTransactionReference,
    t.SageInvoiceNumber,
    t.SageSalesOrderNumber
FROM SFin.Transactions AS t
LEFT JOIN SFin.TransactionSageSubmissionStatus AS s
    ON s.TransactionID = t.ID
    AND s.RowStatus <> 0
    AND s.RowStatus <> 254
WHERE
    t.RowStatus <> 0
    AND t.RowStatus <> 254
    AND t.Batched = 0
    AND NULLIF(LTRIM(RTRIM(ISNULL(t.SageSalesOrderNumber, N''))), N'') IS NULL
    AND ISNULL(s.StatusCode, N'') <> N'Succeeded'
    AND NOT EXISTS
    (
        SELECT 1
        FROM SCore.IntegrationOutbox AS io
        WHERE
            io.RowStatus <> 0
            AND io.RowStatus <> 254
            AND io.EventType = N'TransactionApprovedForSageSubmission'
            AND io.PublishedOnUtc IS NULL
            AND ISJSON(io.PayloadJson) = 1
            AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transactionGuid')) = t.Guid
    )
ORDER BY t.ID DESC;
GO
