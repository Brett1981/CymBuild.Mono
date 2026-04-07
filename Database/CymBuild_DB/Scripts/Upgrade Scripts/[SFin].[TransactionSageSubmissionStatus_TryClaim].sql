USE [CymBuild_Dev]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [SFin].[TransactionSageSubmissionStatus_TryClaim]
(
    @TransactionID         BIGINT,
    @TransactionGuid       UNIQUEIDENTIFIER,
    @TransitionGuid        UNIQUEIDENTIFIER,
    @CreatedByUserID       INT = -1,
    @ClaimTimeoutMinutes   INT = 15
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @StatusID BIGINT,
        @StatusCode NVARCHAR(30),
        @IsInProgress BIT,
        @SageOrderId NVARCHAR(100),
        @SageOrderNumber NVARCHAR(100),
        @InProgressClaimedOnUtc DATETIME2(7),
        @NowUtc DATETIME2(7) = SYSUTCDATETIME(),
        @IsStaleClaim BIT = 0;

    IF (@ClaimTimeoutMinutes IS NULL OR @ClaimTimeoutMinutes < 1)
    BEGIN
        SET @ClaimTimeoutMinutes = 15;
    END;

    EXEC [SFin].[TransactionSageSubmissionStatus_Ensure]
         @TransactionID   = @TransactionID,
         @TransactionGuid = @TransactionGuid,
         @TransitionGuid  = @TransitionGuid,
         @CreatedByUserID = @CreatedByUserID;

    BEGIN TRAN;

    SELECT
        @StatusID = s.ID,
        @StatusCode = s.StatusCode,
        @IsInProgress = s.IsInProgress,
        @SageOrderId = s.SageOrderId,
        @SageOrderNumber = s.SageOrderNumber,
        @InProgressClaimedOnUtc = s.InProgressClaimedOnUtc
    FROM SFin.TransactionSageSubmissionStatus AS s WITH (UPDLOCK, HOLDLOCK)
    WHERE s.TransactionGuid = @TransactionGuid
      AND s.RowStatus NOT IN (0, 254);

    IF (@StatusCode = N'Succeeded')
    BEGIN
        SELECT
            CAST(0 AS bit) AS ClaimAcquired,
            CAST(1 AS bit) AS AlreadyProcessed,
            CAST(0 AS bit) AS InProgressElsewhere,
            CAST(0 AS bit) AS StaleClaimReclaimed,
            @StatusCode AS StatusCode,
            @InProgressClaimedOnUtc AS PreviousClaimedOnUtc,
            ISNULL(@SageOrderId, N'') AS SageOrderId,
            ISNULL(@SageOrderNumber, N'') AS SageOrderNumber,
            N'The transaction has already been successfully submitted to Sage.' AS [Message];

        COMMIT TRAN;
        RETURN;
    END;

    IF (@IsInProgress = 1)
    BEGIN
        IF (@InProgressClaimedOnUtc IS NOT NULL
            AND @InProgressClaimedOnUtc < DATEADD(MINUTE, -@ClaimTimeoutMinutes, @NowUtc))
        BEGIN
            SET @IsStaleClaim = 1;
        END
        ELSE
        BEGIN
            SELECT
                CAST(0 AS bit) AS ClaimAcquired,
                CAST(0 AS bit) AS AlreadyProcessed,
                CAST(1 AS bit) AS InProgressElsewhere,
                CAST(0 AS bit) AS StaleClaimReclaimed,
                @StatusCode AS StatusCode,
                @InProgressClaimedOnUtc AS PreviousClaimedOnUtc,
                ISNULL(@SageOrderId, N'') AS SageOrderId,
                ISNULL(@SageOrderNumber, N'') AS SageOrderNumber,
                N'The transaction is currently being processed elsewhere.' AS [Message];

            COMMIT TRAN;
            RETURN;
        END;
    END;

    UPDATE SFin.TransactionSageSubmissionStatus
    SET
        LastTransitionGuid = @TransitionGuid,
        LastOperationName = N'CreateSalesOrder',
        StatusCode = N'InProgress',
        IsInProgress = 1,
        InProgressClaimedOnUtc = @NowUtc,
        UpdatedDateTimeUTC = @NowUtc,
        UpdatedByUserID = ISNULL(@CreatedByUserID, -1)
    WHERE ID = @StatusID;

    SELECT
        CAST(1 AS bit) AS ClaimAcquired,
        CAST(0 AS bit) AS AlreadyProcessed,
        CAST(0 AS bit) AS InProgressElsewhere,
        @IsStaleClaim AS StaleClaimReclaimed,
        CAST(N'InProgress' AS nvarchar(30)) AS StatusCode,
        @InProgressClaimedOnUtc AS PreviousClaimedOnUtc,
        CAST(N'' AS nvarchar(100)) AS SageOrderId,
        CAST(N'' AS nvarchar(100)) AS SageOrderNumber,
        CASE
            WHEN @IsStaleClaim = 1
                THEN N'Stale claim reclaimed.'
            ELSE N'Claim acquired.'
        END AS [Message];

    COMMIT TRAN;
END;
GO