SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionSageSubmission_Requeue]')
GO
CREATE PROCEDURE [SFin].[TransactionSageSubmission_Requeue]
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