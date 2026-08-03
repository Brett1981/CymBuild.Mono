SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionUnbatch]')
GO
CREATE PROCEDURE [SFin].[TransactionUnbatch]
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
