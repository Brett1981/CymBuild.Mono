SET QUOTED_IDENTIFIER, ANSI_NULLS ON
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
        @TransactionID BIGINT;

    BEGIN TRAN;

    SELECT
        @StatusID = s.ID,
        @TransactionID = s.TransactionID
    FROM SFin.TransactionSageSubmissionStatus AS s WITH (UPDLOCK, HOLDLOCK)
    WHERE s.TransactionGuid = @TransactionGuid
      AND s.RowStatus NOT IN (0, 254);

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