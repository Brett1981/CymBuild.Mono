SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageInboundPaymentSync_Enqueue]')
GO

CREATE PROCEDURE [SFin].[SageInboundPaymentSync_Enqueue]
(
    @CymBuildEntityTypeID   INT = NULL,
    @CymBuildDocumentGuid   UNIQUEIDENTIFIER = NULL,
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

    -------------------------------------------------------------------------
    -- Resolve an existing status row first, if either Guid or TransactionID
    -- was supplied.
    -------------------------------------------------------------------------
    SELECT TOP (1)
        @ExistingID = s.ID,
        @CymBuildEntityTypeID = COALESCE(@CymBuildEntityTypeID, s.CymBuildEntityTypeID),
        @CymBuildDocumentGuid = COALESCE(@CymBuildDocumentGuid, s.CymBuildDocumentGuid),
        @CymBuildDocumentID = COALESCE(@CymBuildDocumentID, s.CymBuildDocumentID),
        @InvoiceRequestID = COALESCE(@InvoiceRequestID, NULLIF(s.InvoiceRequestID, -1)),
        @TransactionID = COALESCE(@TransactionID, NULLIF(s.TransactionID, -1)),
        @JobID = COALESCE(NULLIF(@JobID, -1), NULLIF(s.JobID, -1)),
        @SageDataset = COALESCE(NULLIF(@SageDataset, N''), NULLIF(s.SageDataset, N'')),
        @SageAccountReference = COALESCE(NULLIF(@SageAccountReference, N''), NULLIF(s.SageAccountReference, N'')),
        @SageDocumentNo = COALESCE(NULLIF(@SageDocumentNo, N''), NULLIF(s.SageDocumentNo, N''))
    FROM SFin.SageInboundDocumentStatus AS s
    WHERE s.RowStatus NOT IN (0, 254)
      AND
      (
            (@CymBuildDocumentGuid IS NOT NULL AND s.CymBuildDocumentGuid = @CymBuildDocumentGuid)
         OR (@TransactionID IS NOT NULL AND s.TransactionID = @TransactionID)
      )
    ORDER BY s.ID DESC;

    -------------------------------------------------------------------------
    -- Resolve from SFin.Transactions.
    -- Do not reference InvoiceRequestId here; it does not exist on this table.
    -------------------------------------------------------------------------
    SELECT TOP (1)
        @TransactionID = COALESCE(@TransactionID, t.ID),
        @CymBuildDocumentGuid = COALESCE(@CymBuildDocumentGuid, t.Guid),
        @CymBuildDocumentID = COALESCE(@CymBuildDocumentID, t.ID),
        @JobID = COALESCE(NULLIF(@JobID, -1), NULLIF(t.JobID, -1)),
        @SageDocumentNo =
            COALESCE
            (
                NULLIF(@SageDocumentNo, N''),
                NULLIF(t.SageSalesOrderNumber, N''),
                NULLIF(t.SageInvoiceNumber, N''),
                NULLIF(t.ReservedInvoiceNumber, N''),
                NULLIF(t.Number, N'')
            )
    FROM SFin.Transactions AS t
    WHERE t.RowStatus NOT IN (0, 254)
      AND
      (
            (@CymBuildDocumentGuid IS NOT NULL AND t.Guid = @CymBuildDocumentGuid)
         OR (@TransactionID IS NOT NULL AND t.ID = @TransactionID)
      )
    ORDER BY t.ID DESC;

    IF @CymBuildDocumentGuid IS NULL
    BEGIN
        ;THROW 60100, 'CymBuildDocumentGuid could not be resolved for Sage inbound status enqueue.', 1;
    END;

    IF @TransactionID IS NULL
    BEGIN
        ;THROW 60101, 'No active transaction exists for the supplied Sage inbound enqueue target.', 1;
    END;

    -------------------------------------------------------------------------
    -- Resolve EntityTypeID for finance transactions.
    -------------------------------------------------------------------------
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

    -------------------------------------------------------------------------
    -- Create the status row if it does not already exist.
    -- SageInboundDocumentStatus_Ensure must handle the DataObjects-compliant
    -- insert path.
    -------------------------------------------------------------------------
    SET @InvoiceRequestID = ISNULL(@InvoiceRequestID, -1);
    SET @CymBuildDocumentID = ISNULL(@CymBuildDocumentID, @TransactionID);
    SET @JobID = ISNULL(@JobID, -1);
    SET @SageDataset = ISNULL(@SageDataset, N'');
    SET @SageAccountReference = ISNULL(@SageAccountReference, N'');
    SET @SageDocumentNo = ISNULL(@SageDocumentNo, N'');

    IF @ExistingID IS NULL
    BEGIN
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

        SELECT TOP (1)
            @ExistingID = s.ID
        FROM SFin.SageInboundDocumentStatus AS s
        WHERE s.Guid = @EnsureGuid
          AND s.RowStatus NOT IN (0, 254)
        ORDER BY s.ID DESC;
    END;

    IF @ExistingID IS NULL
    BEGIN
        ;THROW 60103, 'Sage inbound status row could not be created or resolved.', 1;
    END;

    -------------------------------------------------------------------------
    -- Requeue for inbound payment/status sync.
    -------------------------------------------------------------------------
    UPDATE SFin.SageInboundDocumentStatus
    SET
        CymBuildEntityTypeID      = @CymBuildEntityTypeID,
        CymBuildDocumentGuid      = @CymBuildDocumentGuid,
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
        LastErrorIsRetryable      = CASE WHEN @ForceRequeue = 1 THEN CONVERT(BIT, 0) ELSE LastErrorIsRetryable END,
        NextPollDueOnUtc          = @NowUtc,
        PollAttemptCount          = CASE WHEN @ForceRequeue = 1 THEN 0 ELSE PollAttemptCount END,
        IsTerminalState           = 0,
        UpdatedByUserID           = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC        = @NowUtc
    WHERE ID = @ExistingID
      AND RowStatus NOT IN (0, 254);
END;
GO