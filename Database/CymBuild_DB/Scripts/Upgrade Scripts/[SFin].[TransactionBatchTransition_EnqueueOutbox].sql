USE [CymBuild_Dev]
GO

CREATE OR ALTER PROCEDURE [SFin].[TransactionBatchTransition_EnqueueOutbox]
(
    @TransactionBatchTransitionGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @TransitionID BIGINT,
        @TransactionID BIGINT,
        @TransactionGuid UNIQUEIDENTIFIER,
        @Number NVARCHAR(30),
        @JobID INT,
        @AccountID INT,
        @OrganisationalUnitId INT,
        @OccurredOnUtc DATETIME2(7),
        @CreatedByUserId INT,
        @SurveyorUserId INT,
        @PayloadJson NVARCHAR(MAX);

    SELECT
        @TransitionID = tbt.ID,
        @TransactionID = tbt.TransactionID,
        @TransactionGuid = tbt.TransactionGuid,
        @OccurredOnUtc = tbt.DateTimeUTC,
        @CreatedByUserId = tbt.CreatedByUserId,
        @SurveyorUserId = tbt.SurveyorUserId
    FROM SFin.TransactionBatchTransitions AS tbt
    WHERE   tbt.Guid = @TransactionBatchTransitionGuid
        AND tbt.RowStatus NOT IN (0, 254);

    IF @TransitionID IS NULL
        RETURN;

    SELECT
        @Number = t.Number,
        @JobID = t.JobID,
        @AccountID = t.AccountID,
        @OrganisationalUnitId = t.OrganisationalUnitId
    FROM SFin.Transactions AS t
    WHERE   t.ID = @TransactionID
        AND t.Guid = @TransactionGuid
        AND t.RowStatus NOT IN (0, 254);

    IF @TransactionID IS NULL
        RETURN;

    SET @PayloadJson =
    (
        SELECT
            NEWID() AS eventGuid,
            N'TransactionApprovedForSageSubmission' AS eventType,
            @OccurredOnUtc AS occurredOnUtc,
            @TransactionBatchTransitionGuid AS transitionGuid,
            @TransitionID AS transitionId,
            @TransactionGuid AS transactionGuid,
            @TransactionID AS transactionId,
            @Number AS transactionNumber,
            @JobID AS jobId,
            @AccountID AS accountId,
            @OrganisationalUnitId AS organisationalUnitId,
            @CreatedByUserId AS actorIdentityId,
            @SurveyorUserId AS surveyorIdentityId
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

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
        N'TransactionApprovedForSageSubmission',
        @PayloadJson,
        NULL,
        0,
        NULL
    );
END;
GO