USE [CymBuild_Dev]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER FUNCTION [SFin].[tvf_TransactionSageSubmissionMonitor]
(
    @UserID INT
)
RETURNS TABLE
AS
RETURN
(
    WITH LatestOutbox AS
    (
        SELECT
            io.ID,
            io.Guid,
            io.CreatedOnUtc,
            io.PublishingStartedOnUtc,
            io.PublishedOnUtc,
            io.PublishAttempts,
            io.LastError,
            io.PayloadJson,
            TransactionGuid = TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transactionGuid')),
            TransitionGuid  = TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transitionGuid')),
            rn = ROW_NUMBER() OVER
                 (
                     PARTITION BY TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transactionGuid'))
                     ORDER BY io.ID DESC
                 )
        FROM SCore.IntegrationOutbox io
        WHERE io.RowStatus NOT IN (0, 254)
          AND io.EventType = N'TransactionApprovedForSageSubmission'
    ),
    LatestAttempt AS
    (
        SELECT
            a.ID,
            a.SubmissionStatusID,
            a.TransactionID,
            a.TransactionGuid,
            a.TransitionGuid,
            a.AttemptedOnUtc,
            a.CompletedOnUtc,
            a.IsSuccess,
            a.IsRetryableFailure,
            a.SageOrderId,
            a.SageOrderNumber,
            a.ResponseStatus,
            a.ResponseDetail,
            a.ErrorMessage,
            rn = ROW_NUMBER() OVER
                 (
                     PARTITION BY a.TransactionGuid
                     ORDER BY a.AttemptedOnUtc DESC, a.ID DESC
                 )
        FROM SFin.TransactionSageSubmissionAttempts a
        WHERE a.RowStatus NOT IN (0, 254)
    )
    SELECT
        ID = ISNULL(s.ID, -1),
        Guid = t.Guid,
        RowStatus = t.RowStatus,

        TransactionID = t.ID,
        TransactionGuid = t.Guid,
        TransitionGuid = ISNULL(s.LastTransitionGuid, lo.TransitionGuid),

        StatusCode = ISNULL(s.StatusCode, N'Pending'),
        IsInProgress = ISNULL(s.IsInProgress, 0),
        InProgressClaimedOnUtc = s.InProgressClaimedOnUtc,
        LastSucceededOnUtc = s.LastSucceededOnUtc,
        LastFailedOnUtc = s.LastFailedOnUtc,

        SageOrderId = ISNULL(s.SageOrderId, N''),
        SageOrderNumber = ISNULL(s.SageOrderNumber, N''),

        LastError = ISNULL(s.LastError, N''),
        LastErrorIsRetryable = ISNULL(s.LastErrorIsRetryable, 0),

        LatestAttemptedOnUtc = la.AttemptedOnUtc,
        LatestAttemptCompletedOnUtc = la.CompletedOnUtc,
        LatestAttemptIsSuccess = ISNULL(la.IsSuccess, 0),
        LatestAttemptIsRetryableFailure = ISNULL(la.IsRetryableFailure, 0),
        LatestResponseStatus = ISNULL(la.ResponseStatus, N''),
        LatestResponseDetail = ISNULL(la.ResponseDetail, N''),
        LatestAttemptErrorMessage = ISNULL(la.ErrorMessage, N''),

        OutboxID = ISNULL(lo.ID, -1),
        OutboxCreatedOnUtc = lo.CreatedOnUtc,
        OutboxPublishingStartedOnUtc = lo.PublishingStartedOnUtc,
        OutboxPublishedOnUtc = lo.PublishedOnUtc,
        OutboxPublishAttempts = ISNULL(lo.PublishAttempts, 0),
        LatestOutboxError = ISNULL(lo.LastError, N''),

        CanRequeue =
            CAST(
                CASE
                    WHEN ISNULL(s.StatusCode, N'Pending') = N'Succeeded' THEN 0
                    WHEN ISNULL(s.LastErrorIsRetryable, 0) = 1 THEN 1
                    WHEN ISNULL(s.StatusCode, N'Pending') IN (N'Pending', N'InProgress', N'FailedRetryable') THEN 1
                    ELSE 0
                END
            AS bit),

        DataObjectGuid = t.Guid
    FROM SFin.Transactions t
    LEFT JOIN SFin.TransactionSageSubmissionStatus s
        ON s.TransactionGuid = t.Guid
       AND s.RowStatus NOT IN (0, 254)
    LEFT JOIN LatestOutbox lo
        ON lo.TransactionGuid = t.Guid
       AND lo.rn = 1
    LEFT JOIN LatestAttempt la
        ON la.TransactionGuid = t.Guid
       AND la.rn = 1
    WHERE t.RowStatus NOT IN (0, 254)
      AND
      (
            s.ID IS NOT NULL
         OR lo.ID IS NOT NULL
      )
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(t.Guid, @UserID) oscr
      )
);
GO