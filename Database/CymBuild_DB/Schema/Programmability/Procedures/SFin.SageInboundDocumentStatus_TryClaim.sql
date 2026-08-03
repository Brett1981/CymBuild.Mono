SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageInboundDocumentStatus_TryClaim]')
GO
CREATE PROCEDURE [SFin].[SageInboundDocumentStatus_TryClaim]
(
    @CymBuildDocumentGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    IF @CymBuildDocumentGuid IS NULL
       OR @CymBuildDocumentGuid = '00000000-0000-0000-0000-000000000000'
    BEGIN
        THROW 51000,
              'A valid CymBuild document Guid is required.',
              1;
    END;

    DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();

    DECLARE @Claimed TABLE
    (
        [ClaimSucceeded]         BIT              NOT NULL,
        [ID]                     BIGINT           NULL,
        [Guid]                   UNIQUEIDENTIFIER NULL,
        [CymBuildEntityTypeID]   INT              NULL,
        [CymBuildDocumentGuid]   UNIQUEIDENTIFIER NULL,
        [CymBuildDocumentID]     BIGINT           NULL,
        [InvoiceRequestID]       INT              NULL,
        [TransactionID]          BIGINT           NULL,
        [JobID]                  INT              NULL,
        [SageDataset]            NVARCHAR(30)     NULL,
        [SageAccountReference]   NVARCHAR(100)    NULL,
        [SageDocumentNo]         NVARCHAR(100)    NULL,
        [StatusCode]             NVARCHAR(30)     NULL,
        [IsInProgress]           BIT              NULL,
        [InProgressClaimedOnUtc] DATETIME2(7)     NULL
    );

    ;WITH [Claimable] AS
    (
        SELECT TOP (1)
            s.[ID]
        FROM [SFin].[SageInboundDocumentStatus] AS s
            WITH
            (
                UPDLOCK,
                READPAST,
                READCOMMITTEDLOCK,
                ROWLOCK
            )
        WHERE s.[CymBuildDocumentGuid] = @CymBuildDocumentGuid
          AND s.[RowStatus] <> 0
          AND s.[RowStatus] <> 254
          AND ISNULL(s.[IsInProgress], 0) = 0
        ORDER BY
            s.[ID]
    )
    UPDATE s
    SET
        s.[IsInProgress] = 1,
        s.[InProgressClaimedOnUtc] = @NowUtc,
        s.[UpdatedByUserID] = [SCore].[GetCurrentUserId](),
        s.[UpdatedDateTimeUTC] = @NowUtc
    OUTPUT
        CAST(1 AS BIT),
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
        inserted.[InProgressClaimedOnUtc]
    INTO @Claimed
    (
        [ClaimSucceeded],
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
        [InProgressClaimedOnUtc]
    )
    FROM [SFin].[SageInboundDocumentStatus] AS s
    INNER JOIN [Claimable] AS c
        ON c.[ID] = s.[ID];

    IF EXISTS
    (
        SELECT 1
        FROM @Claimed AS c
    )
    BEGIN
        SELECT
            c.[ClaimSucceeded],
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
            c.[InProgressClaimedOnUtc]
        FROM @Claimed AS c;
    END;
    ELSE
    BEGIN
        SELECT
            CAST(0 AS BIT)                   AS [ClaimSucceeded],
            CAST(NULL AS BIGINT)             AS [ID],
            CAST(NULL AS UNIQUEIDENTIFIER)   AS [Guid],
            CAST(NULL AS INT)                AS [CymBuildEntityTypeID],
            CAST(NULL AS UNIQUEIDENTIFIER)   AS [CymBuildDocumentGuid],
            CAST(NULL AS BIGINT)             AS [CymBuildDocumentID],
            CAST(NULL AS INT)                AS [InvoiceRequestID],
            CAST(NULL AS BIGINT)             AS [TransactionID],
            CAST(NULL AS INT)                AS [JobID],
            CAST(NULL AS NVARCHAR(30))       AS [SageDataset],
            CAST(NULL AS NVARCHAR(100))      AS [SageAccountReference],
            CAST(NULL AS NVARCHAR(100))      AS [SageDocumentNo],
            CAST(NULL AS NVARCHAR(30))       AS [StatusCode],
            CAST(NULL AS BIT)                AS [IsInProgress],
            CAST(NULL AS DATETIME2(7))       AS [InProgressClaimedOnUtc];
    END;
END;
GO