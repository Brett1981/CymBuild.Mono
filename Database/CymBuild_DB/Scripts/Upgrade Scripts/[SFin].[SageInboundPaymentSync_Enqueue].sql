
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SFin].[SageInboundPaymentSync_Enqueue]
(
    @CymBuildEntityTypeID   INT = NULL,
    @CymBuildDocumentGuid   UNIQUEIDENTIFIER,
    @CymBuildDocumentID     BIGINT = NULL,
    @InvoiceRequestID       INT = NULL,
    @TransactionID          BIGINT = NULL,
    @JobID                  INT = NULL,
    @SageDataset            NVARCHAR(30) = NULL,
    @SageAccountReference   NVARCHAR(100) = NULL,
    @SageDocumentNo         NVARCHAR(100) = NULL,
    @ForceRequeue           BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @NowUtc     DATETIME2(7) = SYSUTCDATETIME(),
        @ExistingID BIGINT = NULL,
        @EnsureGuid UNIQUEIDENTIFIER = NULL;

    IF @CymBuildDocumentGuid IS NULL
    BEGIN
        ;THROW 60100, 'CymBuildDocumentGuid is required.', 1;
    END;

    SELECT
        @ExistingID = s.ID,
        @CymBuildEntityTypeID = COALESCE(@CymBuildEntityTypeID, s.CymBuildEntityTypeID),
        @CymBuildDocumentID = COALESCE(@CymBuildDocumentID, s.CymBuildDocumentID),
        @InvoiceRequestID = COALESCE(@InvoiceRequestID, s.InvoiceRequestID),
        @TransactionID = COALESCE(@TransactionID, s.TransactionID),
        @JobID = COALESCE(@JobID, s.JobID),
        @SageDataset = COALESCE(NULLIF(@SageDataset, N''), s.SageDataset),
        @SageAccountReference = COALESCE(NULLIF(@SageAccountReference, N''), s.SageAccountReference),
        @SageDocumentNo = COALESCE(NULLIF(@SageDocumentNo, N''), s.SageDocumentNo)
    FROM SFin.SageInboundDocumentStatus AS s
    WHERE s.CymBuildDocumentGuid = @CymBuildDocumentGuid
      AND s.RowStatus NOT IN (0, 254);

    IF @ExistingID IS NULL
    BEGIN
        SELECT TOP (1)
            @TransactionID = COALESCE(@TransactionID, t.ID),
            @CymBuildDocumentID = COALESCE(@CymBuildDocumentID, t.ID),
            @JobID = COALESCE(NULLIF(@JobID, -1), t.JobID),
            @SageDocumentNo = COALESCE(NULLIF(@SageDocumentNo, N''), t.SageSalesOrderNumber, t.SageInvoiceNumber, t.Number)
        FROM SFin.Transactions AS t
        WHERE t.Guid = @CymBuildDocumentGuid
          AND t.RowStatus NOT IN (0, 254);

        IF @TransactionID IS NULL
        BEGIN
            ;THROW 60101, 'No active transaction exists for the supplied CymBuildDocumentGuid, so Sage inbound status cannot be created.', 1;
        END;

        IF @CymBuildEntityTypeID IS NULL
        BEGIN
            SELECT TOP (1)
                @CymBuildEntityTypeID = et.ID
            FROM SCore.EntityTypes AS et
            WHERE et.Name IN (N'Transactions', N'Finance Transactions', N'Transaction')
              AND et.RowStatus NOT IN (0, 254)
            ORDER BY
                CASE et.Name
                    WHEN N'Transactions' THEN 1
                    WHEN N'Finance Transactions' THEN 2
                    WHEN N'Transaction' THEN 3
                    ELSE 4
                END,
                et.ID;
        END;

        IF @CymBuildEntityTypeID IS NULL
        BEGIN
            ;THROW 60102, 'Could not resolve EntityTypeID for SFin.Transactions.', 1;
        END;

        EXEC SFin.SageInboundDocumentStatus_Ensure
             @CymBuildEntityTypeID = @CymBuildEntityTypeID,
             @CymBuildDocumentGuid = @CymBuildDocumentGuid,
             @CymBuildDocumentID = @CymBuildDocumentID,
             @InvoiceRequestID = @InvoiceRequestID,
             @TransactionID = @TransactionID,
             @JobID = @JobID,
             @SageDataset = @SageDataset,
             @SageAccountReference = @SageAccountReference,
             @SageDocumentNo = @SageDocumentNo,
             @Guid = @EnsureGuid OUTPUT;

        SELECT
            @ExistingID = s.ID
        FROM SFin.SageInboundDocumentStatus AS s
        WHERE s.Guid = @EnsureGuid
          AND s.RowStatus NOT IN (0, 254);
    END;

    UPDATE SFin.SageInboundDocumentStatus
    SET
        CymBuildEntityTypeID      = @CymBuildEntityTypeID,
        CymBuildDocumentID        = ISNULL(@CymBuildDocumentID, -1),
        InvoiceRequestID          = ISNULL(@InvoiceRequestID, -1),
        TransactionID             = ISNULL(@TransactionID, -1),
        JobID                     = ISNULL(@JobID, -1),
        SageDataset               = ISNULL(@SageDataset, N''),
        SageAccountReference      = ISNULL(@SageAccountReference, N''),
        SageDocumentNo            = ISNULL(@SageDocumentNo, N''),
        LastOperationName         = N'SyncCustomerTransactions',
        StatusCode                = N'Pending',
        IsInProgress              = 0,
        InProgressClaimedOnUtc    = NULL,
        LastError                 = CASE WHEN @ForceRequeue = 1 THEN N'' ELSE LastError END,
        LastErrorIsRetryable      = CASE WHEN @ForceRequeue = 1 THEN 0 ELSE LastErrorIsRetryable END,
        NextPollDueOnUtc          = @NowUtc,
        PollAttemptCount          = CASE WHEN @ForceRequeue = 1 THEN 0 ELSE PollAttemptCount END,
        IsTerminalState           = 0,
        UpdatedByUserID           = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC        = @NowUtc
    WHERE ID = @ExistingID
      AND RowStatus NOT IN (0, 254);
END;
GO