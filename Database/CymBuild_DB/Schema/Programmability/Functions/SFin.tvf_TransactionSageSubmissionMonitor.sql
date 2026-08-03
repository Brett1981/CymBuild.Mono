SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[tvf_TransactionSageSubmissionMonitor]')
GO
PRINT (N'Create function [SFin].[tvf_TransactionSageSubmissionMonitor]')
GO
PRINT (N'Create function [SFin].[tvf_TransactionSageSubmissionMonitor]')
GO
PRINT (N'Create function [SFin].[tvf_TransactionSageSubmissionMonitor]')
GO

/*
    CYB-445 - Exclude legacy-posted transactions from the automated
              Sage Posting Status monitor.

    A transaction is treated as legacy-posted when:
      - it has active manual Sage Export membership; or
      - it has a non-empty SageTransactionReference.

    Automated Succeeded records remain visible for diagnostics.
    Non-succeeded legacy-posted records are excluded and cannot be requeued.
*/

CREATE FUNCTION [SFin].[tvf_TransactionSageSubmissionMonitor]
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
            TransactionGuid =
                TRY_CONVERT
                (
                    UNIQUEIDENTIFIER,
                    JSON_VALUE
                    (
                        CASE
                            WHEN ISJSON(io.PayloadJson) = 1
                                THEN io.PayloadJson
                            ELSE N'{}'
                        END,
                        '$.transactionGuid'
                    )
                ),
            TransitionGuid =
                TRY_CONVERT
                (
                    UNIQUEIDENTIFIER,
                    JSON_VALUE
                    (
                        CASE
                            WHEN ISJSON(io.PayloadJson) = 1
                                THEN io.PayloadJson
                            ELSE N'{}'
                        END,
                        '$.transitionGuid'
                    )
                ),
            rn =
                ROW_NUMBER() OVER
                (
                    PARTITION BY
                        TRY_CONVERT
                        (
                            UNIQUEIDENTIFIER,
                            JSON_VALUE
                            (
                                CASE
                                    WHEN ISJSON(io.PayloadJson) = 1
                                        THEN io.PayloadJson
                                    ELSE N'{}'
                                END,
                                '$.transactionGuid'
                            )
                        )
                    ORDER BY io.ID DESC
                )
        FROM SCore.IntegrationOutbox AS io
        WHERE io.RowStatus <> 0
          AND io.RowStatus <> 254
          AND io.EventType = N'TransactionApprovedForSageSubmission'
          AND ISJSON(io.PayloadJson) = 1
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
            rn =
                ROW_NUMBER() OVER
                (
                    PARTITION BY a.TransactionGuid
                    ORDER BY
                        a.AttemptedOnUtc DESC,
                        a.ID DESC
                )
        FROM SFin.TransactionSageSubmissionAttempts AS a
        WHERE a.RowStatus <> 0
          AND a.RowStatus <> 254
    ),
    LegacyPostedTransactions AS
    (
        SELECT
            t.ID AS TransactionID
        FROM SFin.Transactions AS t
        WHERE t.RowStatus <> 0
          AND t.RowStatus <> 254
          AND
          (
              NULLIF
              (
                  LTRIM
                  (
                      RTRIM
                      (
                          ISNULL(t.SageTransactionReference, N'')
                      )
                  ),
                  N''
              ) IS NOT NULL
              OR EXISTS
              (
                  SELECT 1
                  FROM SFin.SageExportTransactions AS setr
                  INNER JOIN SFin.SageExports AS se
                      ON se.ID = setr.SageExportID
                     AND se.RowStatus <> 0
                     AND se.RowStatus <> 254
                  WHERE setr.TransactionID = t.ID
                    AND setr.RowStatus <> 0
                    AND setr.RowStatus <> 254
              )
          )
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
        LatestAttemptIsRetryableFailure =
            ISNULL(la.IsRetryableFailure, 0),
        LatestResponseStatus = ISNULL(la.ResponseStatus, N''),
        LatestResponseDetail = ISNULL(la.ResponseDetail, N''),
        LatestAttemptErrorMessage = ISNULL(la.ErrorMessage, N''),

        OutboxID = ISNULL(lo.ID, -1),
        OutboxCreatedOnUtc = lo.CreatedOnUtc,
        OutboxPublishingStartedOnUtc = lo.PublishingStartedOnUtc,
        OutboxPublishedOnUtc = lo.PublishedOnUtc,
        OutboxPublishAttempts = ISNULL(lo.PublishAttempts, 0),
        LatestOutboxError = ISNULL(lo.LastError, N''),

        Department = ISNULL(org.Name, N''),
        BusinessUnit = ISNULL(org2.Name, N''),

        CanRequeue =
            CAST
            (
                CASE
                    WHEN ISNULL(s.StatusCode, N'Pending') = N'Succeeded'
                        THEN 0
                    WHEN ISNULL(s.LastErrorIsRetryable, 0) = 1
                        THEN 1
                    WHEN ISNULL(s.StatusCode, N'Pending') IN
                         (
                             N'Pending',
                             N'InProgress',
                             N'FailedRetryable'
                         )
                        THEN 1
                    ELSE 0
                END
                AS bit
            ),

        DataObjectGuid = t.Guid
    FROM SFin.Transactions AS t
    LEFT JOIN SFin.TransactionSageSubmissionStatus AS s
        ON s.TransactionGuid = t.Guid
       AND s.RowStatus <> 0
       AND s.RowStatus <> 254
    LEFT JOIN LatestOutbox AS lo
        ON lo.TransactionGuid = t.Guid
       AND lo.rn = 1
    LEFT JOIN LatestAttempt AS la
        ON la.TransactionGuid = t.Guid
       AND la.rn = 1
    LEFT JOIN LegacyPostedTransactions AS legacy
        ON legacy.TransactionID = t.ID
    LEFT JOIN SCore.OrganisationalUnits AS org
        ON org.ID = t.OrganisationalUnitId
       AND org.RowStatus <> 0
       AND org.RowStatus <> 254
    LEFT JOIN SCore.OrganisationalUnits AS org2
        ON org2.ID = org.ParentID
       AND org2.RowStatus <> 0
       AND org2.RowStatus <> 254
    WHERE t.RowStatus <> 0
      AND t.RowStatus <> 254
      AND
      (
            s.ID IS NOT NULL
         OR lo.ID IS NOT NULL
      )
      AND
      (
            ISNULL(s.StatusCode, N'Pending') = N'Succeeded'
         OR legacy.TransactionID IS NULL
      )
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead
          (
              t.Guid,
              @UserID
          ) AS oscr
      )
);
GO