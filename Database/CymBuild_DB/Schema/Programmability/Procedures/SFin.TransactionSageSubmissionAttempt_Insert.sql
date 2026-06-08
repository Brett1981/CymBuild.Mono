SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionSageSubmissionAttempt_Insert]')
GO

CREATE PROCEDURE [SFin].[TransactionSageSubmissionAttempt_Insert]
(
    @SubmissionStatusID  BIGINT,
    @TransactionID       BIGINT,
    @TransactionGuid     UNIQUEIDENTIFIER,
    @TransitionGuid      UNIQUEIDENTIFIER,
    @OperationName       NVARCHAR(100),
    @IsSuccess           BIT,
    @IsRetryableFailure  BIT,
    @SageOrderId         NVARCHAR(100) = NULL,
    @SageOrderNumber     NVARCHAR(100) = NULL,
    @ResponseStatus      NVARCHAR(50) = NULL,
    @ResponseDetail      NVARCHAR(MAX) = NULL,
    @ErrorMessage        NVARCHAR(MAX) = NULL,
    @RequestPayloadJson  NVARCHAR(MAX) = NULL,
    @ResponsePayloadJson NVARCHAR(MAX) = NULL,
    @CreatedByUserID     INT = -1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @AttemptGuid UNIQUEIDENTIFIER = NEWID();
    DECLARE @IsInsert BIT;

    EXEC SCore.UpsertDataObject
         @Guid       = @AttemptGuid,
         @SchemeName = N'SFin',
         @ObjectName = N'TransactionSageSubmissionAttempts',
         @IsInsert   = @IsInsert OUTPUT;

    INSERT INTO SFin.TransactionSageSubmissionAttempts
    (
        RowStatus,
        Guid,
        SubmissionStatusID,
        TransactionID,
        TransactionGuid,
        TransitionGuid,
        OperationName,
        AttemptedOnUtc,
        CompletedOnUtc,
        IsSuccess,
        IsRetryableFailure,
        SageOrderId,
        SageOrderNumber,
        ResponseStatus,
        ResponseDetail,
        ErrorMessage,
        RequestPayloadJson,
        ResponsePayloadJson,
        CreatedDateTimeUTC,
        CreatedByUserID
    )
    VALUES
    (
        1,
        @AttemptGuid,
        @SubmissionStatusID,
        @TransactionID,
        @TransactionGuid,
        @TransitionGuid,
        ISNULL(@OperationName, N'CreateSalesOrder'),
        SYSUTCDATETIME(),
        SYSUTCDATETIME(),
        ISNULL(@IsSuccess, 0),
        ISNULL(@IsRetryableFailure, 0),
        @SageOrderId,
        @SageOrderNumber,
        @ResponseStatus,
        @ResponseDetail,
        @ErrorMessage,
        @RequestPayloadJson,
        @ResponsePayloadJson,
        SYSUTCDATETIME(),
        ISNULL(@CreatedByUserID, -1)
    );
END;
GO