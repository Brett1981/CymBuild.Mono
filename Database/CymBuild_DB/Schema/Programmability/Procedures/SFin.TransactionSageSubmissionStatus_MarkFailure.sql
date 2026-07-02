SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionSageSubmissionStatus_MarkFailure]')
GO
PRINT (N'Create procedure [SFin].[TransactionSageSubmissionStatus_MarkFailure]')
GO

CREATE PROCEDURE [SFin].[TransactionSageSubmissionStatus_MarkFailure]
(
    @TransactionGuid     UNIQUEIDENTIFIER,
    @TransitionGuid      UNIQUEIDENTIFIER,
    @ErrorMessage        NVARCHAR(MAX),
    @IsRetryable         BIT,
    @ResponseStatus      NVARCHAR(50) = NULL,
    @ResponseDetail      NVARCHAR(MAX) = NULL,
    @RequestPayloadJson  NVARCHAR(MAX) = NULL,
    @ResponsePayloadJson NVARCHAR(MAX) = NULL,
    @UpdatedByUserID     INT = -1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @StatusID BIGINT,
        @TransactionID BIGINT,
        @CurrentStatusCode NVARCHAR(30),
        @LastSucceededOnUtc DATETIME2(7),
        @SageOrderId NVARCHAR(100),
        @SageOrderNumber NVARCHAR(100),
        @ExistingSageTransactionReference NVARCHAR(100),
        @ExistingSageInvoiceNumber NVARCHAR(100),
        @ExistingSageSalesOrderNumber NVARCHAR(100);

    BEGIN TRAN;

    SELECT
        @StatusID = s.ID,
        @TransactionID = s.TransactionID,
        @CurrentStatusCode = s.StatusCode,
        @LastSucceededOnUtc = s.LastSucceededOnUtc,
        @SageOrderId = s.SageOrderId,
        @SageOrderNumber = s.SageOrderNumber
    FROM SFin.TransactionSageSubmissionStatus AS s WITH (UPDLOCK, HOLDLOCK)
    WHERE s.TransactionGuid = @TransactionGuid
      AND s.RowStatus NOT IN (0,254);

    IF ISNULL(@StatusID, -1) <= 0
    BEGIN
        ROLLBACK TRAN;
        THROW 60132, N'Transaction Sage submission status row not found while marking Sage submission failure.', 1;
    END;

    SELECT
        @ExistingSageTransactionReference = t.SageTransactionReference,
        @ExistingSageInvoiceNumber = t.SageInvoiceNumber,
        @ExistingSageSalesOrderNumber = t.SageSalesOrderNumber
    FROM SFin.Transactions AS t WITH (UPDLOCK, HOLDLOCK)
    WHERE t.ID = @TransactionID
      AND t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0,254);

    -------------------------------------------------------------------------
    -- CYB-414
    -- Do not allow a secondary post-success process failure to demote an
    -- already successful Sage submission.
    --
    -- Example:
    -- 1. Sage order/invoice is created successfully.
    -- 2. Transaction Sage reference is persisted.
    -- 3. Follow-up inbound enqueue cannot resolve a target.
    --
    -- The follow-up failure is not an outbound posting failure and must not:
    -- - overwrite StatusCode from Succeeded to FailedNonRetryable
    -- - return the transaction to the batch
    -- - remove or obscure Sage reference/order information
    -------------------------------------------------------------------------
    IF
    (
           @CurrentStatusCode = N'Succeeded'
        OR @LastSucceededOnUtc IS NOT NULL
        OR NULLIF(LTRIM(RTRIM(ISNULL(@SageOrderId, N''))), N'') IS NOT NULL
        OR NULLIF(LTRIM(RTRIM(ISNULL(@SageOrderNumber, N''))), N'') IS NOT NULL
        OR NULLIF(LTRIM(RTRIM(ISNULL(@ExistingSageTransactionReference, N''))), N'') IS NOT NULL
        OR NULLIF(LTRIM(RTRIM(ISNULL(@ExistingSageInvoiceNumber, N''))), N'') IS NOT NULL
        OR NULLIF(LTRIM(RTRIM(ISNULL(@ExistingSageSalesOrderNumber, N''))), N'') IS NOT NULL
    )
    BEGIN
        UPDATE s
        SET
            s.LastTransitionGuid = ISNULL(@TransitionGuid, s.LastTransitionGuid),
            s.LastOperationName = N'CreateSalesOrder',
            s.StatusCode = N'Succeeded',
            s.IsInProgress = 0,
            s.InProgressClaimedOnUtc = NULL,
            s.LastError = NULL,
            s.LastErrorIsRetryable = NULL,
            s.UpdatedDateTimeUTC = SYSUTCDATETIME(),
            s.UpdatedByUserID = ISNULL(@UpdatedByUserID, -1)
        FROM SFin.TransactionSageSubmissionStatus AS s
        WHERE s.ID = @StatusID
          AND s.RowStatus NOT IN (0,254);

        COMMIT TRAN;
        RETURN;
    END;

    UPDATE SFin.TransactionSageSubmissionStatus
    SET
        LastTransitionGuid = @TransitionGuid,
        LastOperationName = N'CreateSalesOrder',
        StatusCode = CASE WHEN @IsRetryable = 1 THEN N'FailedRetryable' ELSE N'FailedNonRetryable' END,
        IsInProgress = 0,
        InProgressClaimedOnUtc = NULL,
        LastFailedOnUtc = SYSUTCDATETIME(),
        LastError = @ErrorMessage,
        LastErrorIsRetryable = @IsRetryable,
        UpdatedDateTimeUTC = SYSUTCDATETIME(),
        UpdatedByUserID = ISNULL(@UpdatedByUserID, -1)
    WHERE ID = @StatusID;

    EXEC [SFin].[TransactionSageSubmissionAttempt_Insert]
         @SubmissionStatusID  = @StatusID,
         @TransactionID       = @TransactionID,
         @TransactionGuid     = @TransactionGuid,
         @TransitionGuid      = @TransitionGuid,
         @OperationName       = N'CreateSalesOrder',
         @IsSuccess           = 0,
         @IsRetryableFailure  = @IsRetryable,
         @SageOrderId         = NULL,
         @SageOrderNumber     = NULL,
         @ResponseStatus      = @ResponseStatus,
         @ResponseDetail      = @ResponseDetail,
         @ErrorMessage        = @ErrorMessage,
         @RequestPayloadJson  = @RequestPayloadJson,
         @ResponsePayloadJson = @ResponsePayloadJson,
         @CreatedByUserID     = @UpdatedByUserID;

    IF (@IsRetryable = 0)
    BEGIN
        EXEC [SFin].[Transaction_ReturnToBatch]
             @TransactionGuid = @TransactionGuid,
             @UpdatedByUserID = @UpdatedByUserID;
    END;

    COMMIT TRAN;
END;
GO