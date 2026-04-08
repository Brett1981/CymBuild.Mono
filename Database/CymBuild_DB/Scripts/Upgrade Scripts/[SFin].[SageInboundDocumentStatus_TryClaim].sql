CREATE OR ALTER PROCEDURE [SFin].[SageInboundDocumentStatus_TryClaim]
(
    @CymBuildDocumentGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2(7) = GETUTCDATE();

    ;WITH Claimable AS
    (
        SELECT TOP (1)
               s.ID
        FROM SFin.SageInboundDocumentStatus s WITH (UPDLOCK, ROWLOCK, READPAST)
        WHERE s.CymBuildDocumentGuid = @CymBuildDocumentGuid
          AND s.RowStatus NOT IN (0,254)
          AND s.IsInProgress = 0
        ORDER BY s.ID
    )
    UPDATE s
    SET
        IsInProgress           = 1,
        InProgressClaimedOnUtc = @NowUtc,
        UpdatedByUserID        = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC     = @NowUtc
    OUTPUT
        CAST(1 AS BIT)                 AS ClaimSucceeded,
        inserted.ID                    AS ID,
        inserted.Guid                  AS Guid,
        inserted.CymBuildEntityTypeID  AS CymBuildEntityTypeID,
        inserted.CymBuildDocumentGuid  AS CymBuildDocumentGuid,
        inserted.CymBuildDocumentID    AS CymBuildDocumentID,
        inserted.InvoiceRequestID      AS InvoiceRequestID,
        inserted.TransactionID         AS TransactionID,
        inserted.JobID                 AS JobID,
        inserted.SageDataset           AS SageDataset,
        inserted.SageAccountReference  AS SageAccountReference,
        inserted.SageDocumentNo        AS SageDocumentNo,
        inserted.StatusCode            AS StatusCode,
        inserted.IsInProgress          AS IsInProgress,
        inserted.InProgressClaimedOnUtc AS InProgressClaimedOnUtc
    FROM SFin.SageInboundDocumentStatus s
    JOIN Claimable c ON c.ID = s.ID;

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT
            CAST(0 AS BIT) AS ClaimSucceeded,
            CAST(NULL AS BIGINT) AS ID,
            CAST(NULL AS UNIQUEIDENTIFIER) AS Guid,
            CAST(NULL AS INT) AS CymBuildEntityTypeID,
            CAST(NULL AS UNIQUEIDENTIFIER) AS CymBuildDocumentGuid,
            CAST(NULL AS BIGINT) AS CymBuildDocumentID,
            CAST(NULL AS INT) AS InvoiceRequestID,
            CAST(NULL AS BIGINT) AS TransactionID,
            CAST(NULL AS INT) AS JobID,
            CAST(NULL AS NVARCHAR(30)) AS SageDataset,
            CAST(NULL AS NVARCHAR(100)) AS SageAccountReference,
            CAST(NULL AS NVARCHAR(100)) AS SageDocumentNo,
            CAST(NULL AS NVARCHAR(30)) AS StatusCode,
            CAST(NULL AS BIT) AS IsInProgress,
            CAST(NULL AS DATETIME2(7)) AS InProgressClaimedOnUtc;
    END
END;
GO