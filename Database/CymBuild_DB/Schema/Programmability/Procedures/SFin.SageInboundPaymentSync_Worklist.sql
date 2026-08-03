SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageInboundPaymentSync_Worklist]')
GO
CREATE PROCEDURE [SFin].[SageInboundPaymentSync_Worklist]
(
    @BatchSize INT = 25,
    @StaleClaimMinutes INT = 15
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    IF @BatchSize IS NULL
       OR @BatchSize < 1
       OR @BatchSize > 500
    BEGIN
        THROW 51000,
              'Batch size must be between 1 and 500.',
              1;
    END;

    IF @StaleClaimMinutes IS NULL
       OR @StaleClaimMinutes < 1
       OR @StaleClaimMinutes > 1440
    BEGIN
        THROW 51001,
              'Stale claim minutes must be between 1 and 1440.',
              1;
    END;

    DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();

    DECLARE @Claimed TABLE
    (
        [ID]                     BIGINT           NOT NULL,
        [Guid]                   UNIQUEIDENTIFIER NOT NULL,
        [CymBuildEntityTypeID]   INT              NOT NULL,
        [CymBuildDocumentGuid]   UNIQUEIDENTIFIER NOT NULL,
        [CymBuildDocumentID]     BIGINT           NOT NULL,
        [InvoiceRequestID]       INT              NOT NULL,
        [TransactionID]          BIGINT           NOT NULL,
        [JobID]                  INT              NOT NULL,
        [SageDataset]            NVARCHAR(250)    NOT NULL,
        [SageAccountReference]   NVARCHAR(250)    NOT NULL,
        [SageDocumentNo]         NVARCHAR(250)    NOT NULL,
        [StatusCode]             NVARCHAR(50)     NOT NULL,
        [IsInProgress]           BIT              NULL,
        [InProgressClaimedOnUtc] DATETIME2(7)     NULL,
        [LastSucceededOnUtc]     DATETIME2(7)     NULL,
        [LastFailedOnUtc]        DATETIME2(7)     NULL,
        [LastError]              NVARCHAR(MAX)    NULL,
        [LastErrorIsRetryable]   BIT              NULL
    );

    ;WITH [Claimable] AS
    (
        SELECT TOP (@BatchSize)
            s.[ID]
        FROM [SFin].[SageInboundDocumentStatus] AS s
            WITH
            (
                UPDLOCK,
                READPAST,
                READCOMMITTEDLOCK,
                ROWLOCK
            )
        WHERE s.[RowStatus] <> 0
          AND s.[RowStatus] <> 254
          AND ISNULL(s.[IsTerminalState], 0) = 0
          AND
          (
              ISNULL(s.[IsInProgress], 0) = 0
              OR
              (
                  s.[IsInProgress] = 1
                  AND s.[InProgressClaimedOnUtc] IS NOT NULL
                  AND DATEADD
                      (
                          MINUTE,
                          @StaleClaimMinutes,
                          s.[InProgressClaimedOnUtc]
                      ) <= @NowUtc
              )
          )
          AND
          (
              s.[NextPollDueOnUtc] IS NULL
              OR s.[NextPollDueOnUtc] <= @NowUtc
          )
        ORDER BY
            CASE
                WHEN s.[StatusCode] = N'PartiallyPaid' THEN 0
                WHEN s.[StatusCode] = N'RetryPending' THEN 1
                WHEN s.[StatusCode] = N'Pending' THEN 2
                ELSE 3
            END,
            ISNULL
            (
                s.[NextPollDueOnUtc],
                CONVERT(DATETIME2(7), '19000101', 112)
            ),
            s.[ID]
    )
    UPDATE s
    SET
        s.[IsInProgress] = 1,
        s.[InProgressClaimedOnUtc] = @NowUtc,
        s.[StatusCode] =
            CASE
                WHEN s.[StatusCode] IN
                     (
                         N'Pending',
                         N'RetryPending',
                         N'PartiallyPaid'
                     )
                    THEN N'InProgress'
                ELSE s.[StatusCode]
            END,
        s.[UpdatedByUserID] = [SCore].[GetCurrentUserId](),
        s.[UpdatedDateTimeUTC] = @NowUtc
    OUTPUT
        inserted.[ID],
        inserted.[Guid],
        inserted.[CymBuildEntityTypeID],
        inserted.[CymBuildDocumentGuid],
        inserted.[CymBuildDocumentID],
        inserted.[InvoiceRequestID],
        inserted.[TransactionID],
        inserted.[JobID],
        inserted.[SageDataset],
        inserted.[SageAccountReference],
        inserted.[SageDocumentNo],
        inserted.[StatusCode],
        inserted.[IsInProgress],
        inserted.[InProgressClaimedOnUtc],
        inserted.[LastSucceededOnUtc],
        inserted.[LastFailedOnUtc],
        inserted.[LastError],
        inserted.[LastErrorIsRetryable]
    INTO @Claimed
    (
        [ID],
        [Guid],
        [CymBuildEntityTypeID],
        [CymBuildDocumentGuid],
        [CymBuildDocumentID],
        [InvoiceRequestID],
        [TransactionID],
        [JobID],
        [SageDataset],
        [SageAccountReference],
        [SageDocumentNo],
        [StatusCode],
        [IsInProgress],
        [InProgressClaimedOnUtc],
        [LastSucceededOnUtc],
        [LastFailedOnUtc],
        [LastError],
        [LastErrorIsRetryable]
    )
    FROM [SFin].[SageInboundDocumentStatus] AS s
    INNER JOIN [Claimable] AS c
        ON c.[ID] = s.[ID];

    SELECT
        c.[ID],
        c.[Guid],
        c.[CymBuildEntityTypeID],
        c.[CymBuildDocumentGuid],
        c.[CymBuildDocumentID],
        c.[InvoiceRequestID],
        c.[TransactionID],
        c.[JobID],
        c.[SageDataset],
        c.[SageAccountReference],
        c.[SageDocumentNo],
        c.[StatusCode],
        c.[IsInProgress],
        c.[InProgressClaimedOnUtc],
        c.[LastSucceededOnUtc],
        c.[LastFailedOnUtc],
        c.[LastError],
        c.[LastErrorIsRetryable]
    FROM @Claimed AS c
    ORDER BY
        c.[ID];
END;
GO