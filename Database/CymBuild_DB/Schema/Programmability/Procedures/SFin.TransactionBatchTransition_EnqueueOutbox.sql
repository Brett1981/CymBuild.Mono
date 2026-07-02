SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionBatchTransition_EnqueueOutbox]')
GO
PRINT (N'Create procedure [SFin].[TransactionBatchTransition_EnqueueOutbox]')
GO

CREATE PROCEDURE [SFin].[TransactionBatchTransition_EnqueueOutbox]
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
        @PayloadJson NVARCHAR(MAX),
        @TransactionResolved BIT = 0;

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
    BEGIN
        RETURN;
    END;

    SELECT
        @TransactionResolved = 1,
        @Number = t.Number,
        @JobID = t.JobID,
        @AccountID = t.AccountID,
        @OrganisationalUnitId = t.OrganisationalUnitId
    FROM SFin.Transactions AS t
    WHERE   t.ID = @TransactionID
        AND t.Guid = @TransactionGuid
        AND t.RowStatus NOT IN (0, 254);

    IF ISNULL(@TransactionResolved, 0) = 0
    BEGIN
        RETURN;
    END;

    -------------------------------------------------------------------------
    -- CYB-414
    -- Do not enqueue Sage submission if the transaction already has confirmed
    -- Sage success/reference.
    -------------------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM SFin.Transactions AS t
        LEFT JOIN SFin.TransactionSageSubmissionStatus AS s
            ON s.TransactionGuid = t.Guid
           AND s.RowStatus NOT IN (0, 254)
        WHERE t.ID = @TransactionID
          AND t.Guid = @TransactionGuid
          AND t.RowStatus NOT IN (0, 254)
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
        RETURN;
    END;

    -------------------------------------------------------------------------
    -- CYB-414
    -- Do not enqueue a second active/unpublished event for the same transaction.
    -- Published historical events are preserved for auditability.
    -------------------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM SCore.IntegrationOutbox AS io
        WHERE io.RowStatus NOT IN (0, 254)
          AND io.EventType = N'TransactionApprovedForSageSubmission'
          AND io.PublishedOnUtc IS NULL
          AND ISJSON(io.PayloadJson) = 1
          AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transactionGuid')) = @TransactionGuid
    )
    BEGIN
        RETURN;
    END;

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
            ISNULL(@CreatedByUserId, -1) AS actorIdentityId,
            ISNULL(@SurveyorUserId, -1) AS surveyorIdentityId
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