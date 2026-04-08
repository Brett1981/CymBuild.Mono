CREATE OR ALTER PROCEDURE [SFin].[SageInboundDocumentStatus_Ensure]
(
    @CymBuildEntityTypeID   INT,
    @CymBuildDocumentGuid   UNIQUEIDENTIFIER,
    @CymBuildDocumentID     BIGINT,
    @InvoiceRequestID       INT,
    @TransactionID          BIGINT,
    @JobID                  INT,
    @SageDataset            NVARCHAR(30),
    @SageAccountReference   NVARCHAR(100),
    @SageDocumentNo         NVARCHAR(100),
    @Guid                   UNIQUEIDENTIFIER OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2(7) = GETUTCDATE();

    IF EXISTS
    (
        SELECT 1
        FROM SFin.SageInboundDocumentStatus s
        WHERE s.CymBuildDocumentGuid = @CymBuildDocumentGuid
          AND s.RowStatus NOT IN (0,254)
    )
    BEGIN
        SELECT
            @Guid = s.Guid
        FROM SFin.SageInboundDocumentStatus s
        WHERE s.CymBuildDocumentGuid = @CymBuildDocumentGuid
          AND s.RowStatus NOT IN (0,254);

        UPDATE s
        SET
            CymBuildEntityTypeID = @CymBuildEntityTypeID,
            CymBuildDocumentID   = @CymBuildDocumentID,
            InvoiceRequestID     = @InvoiceRequestID,
            TransactionID        = @TransactionID,
            JobID                = @JobID,
            SageDataset          = @SageDataset,
            SageAccountReference = @SageAccountReference,
            SageDocumentNo       = @SageDocumentNo,
            UpdatedByUserID      = SCore.GetCurrentUserId(),
            UpdatedDateTimeUTC   = @NowUtc
        FROM SFin.SageInboundDocumentStatus s
        WHERE s.Guid = @Guid;

        RETURN;
    END;

    IF (@Guid IS NULL OR @Guid = '00000000-0000-0000-0000-000000000000')
    BEGIN
        SET @Guid = NEWID();
    END;

    DECLARE @IsInsert BIT;

    EXEC SCore.UpsertDataObject
         @Guid       = @Guid,
         @SchemeName = N'SFin',
         @ObjectName = N'SageInboundDocumentStatus',
         @IsInsert   = @IsInsert OUTPUT;

    INSERT INTO SFin.SageInboundDocumentStatus
    (
        RowStatus,
        Guid,
        CymBuildEntityTypeID,
        CymBuildDocumentGuid,
        CymBuildDocumentID,
        InvoiceRequestID,
        TransactionID,
        JobID,
        SageDataset,
        SageAccountReference,
        SageDocumentNo,
        LastOperationName,
        StatusCode,
        IsInProgress,
        InProgressClaimedOnUtc,
        LastSucceededOnUtc,
        LastFailedOnUtc,
        LastError,
        LastErrorIsRetryable,
        LastSourceWatermarkUtc,
        CreatedByUserID,
        CreatedDateTimeUTC,
        UpdatedByUserID,
        UpdatedDateTimeUTC
    )
    VALUES
    (
        1,
        @Guid,
        @CymBuildEntityTypeID,
        @CymBuildDocumentGuid,
        @CymBuildDocumentID,
        @InvoiceRequestID,
        @TransactionID,
        @JobID,
        @SageDataset,
        @SageAccountReference,
        @SageDocumentNo,
        N'SyncCustomerTransactions',
        N'Pending',
        0,
        NULL,
        NULL,
        NULL,
        N'',
        NULL,
        NULL,
        SCore.GetCurrentUserId(),
        @NowUtc,
        SCore.GetCurrentUserId(),
        @NowUtc
    );
END;
GO