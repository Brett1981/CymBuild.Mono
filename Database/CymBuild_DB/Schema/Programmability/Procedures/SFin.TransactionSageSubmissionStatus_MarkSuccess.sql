SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionSageSubmissionStatus_MarkSuccess]')
GO

CREATE PROCEDURE [SFin].[TransactionSageSubmissionStatus_MarkSuccess]
(
    @TransactionGuid     UNIQUEIDENTIFIER,
    @TransitionGuid      UNIQUEIDENTIFIER,
    @SageOrderId         NVARCHAR(100),
    @SageOrderNumber     NVARCHAR(100),
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
        @NowUtc DATETIME2(7) = SYSUTCDATETIME();

    BEGIN TRAN;

    SELECT
        @StatusID = s.ID,
        @TransactionID = s.TransactionID
    FROM SFin.TransactionSageSubmissionStatus AS s WITH (UPDLOCK, HOLDLOCK)
    WHERE s.TransactionGuid = @TransactionGuid
      AND s.RowStatus NOT IN (0, 254);

    IF ISNULL(@StatusID, -1) <= 0
    BEGIN
        ROLLBACK TRAN;
        RAISERROR('Transaction Sage submission status row not found.', 16, 1);
        RETURN;
    END;

    UPDATE SFin.TransactionSageSubmissionStatus
    SET
        LastTransitionGuid = @TransitionGuid,
        LastOperationName = N'CreateSalesOrder',
        StatusCode = N'Succeeded',
        IsInProgress = 0,
        InProgressClaimedOnUtc = NULL,
        LastSucceededOnUtc = @NowUtc,
        SageOrderId = @SageOrderId,
        SageOrderNumber = @SageOrderNumber,
        LastError = NULL,
        LastErrorIsRetryable = NULL,
        UpdatedDateTimeUTC = @NowUtc,
        UpdatedByUserID = ISNULL(@UpdatedByUserID, -1)
    WHERE ID = @StatusID;

    /*
        CRITICAL CYB-214 FIX
        Persist the Sage-returned invoice number onto the posted transaction so
        inbound Sage payment sync can reconcile back to the CymBuild invoice.
    */
    UPDATE t
    SET
        ReservedInvoiceNumber = @SageOrderNumber
    FROM SFin.Transactions AS t
    WHERE t.ID = @TransactionID
      AND t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254)
      AND ISNULL(@SageOrderNumber, N'') <> N'';

    EXEC [SFin].[TransactionSageSubmissionAttempt_Insert]
         @SubmissionStatusID  = @StatusID,
         @TransactionID       = @TransactionID,
         @TransactionGuid     = @TransactionGuid,
         @TransitionGuid      = @TransitionGuid,
         @OperationName       = N'CreateSalesOrder',
         @IsSuccess           = 1,
         @IsRetryableFailure  = 0,
         @SageOrderId         = @SageOrderId,
         @SageOrderNumber     = @SageOrderNumber,
         @ResponseStatus      = @ResponseStatus,
         @ResponseDetail      = @ResponseDetail,
         @ErrorMessage        = NULL,
         @RequestPayloadJson  = @RequestPayloadJson,
         @ResponsePayloadJson = @ResponsePayloadJson,
         @CreatedByUserID     = @UpdatedByUserID;

    COMMIT TRAN;
END;
GO