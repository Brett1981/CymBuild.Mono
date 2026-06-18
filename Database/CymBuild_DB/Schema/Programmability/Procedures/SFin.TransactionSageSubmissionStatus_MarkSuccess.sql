SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionSageSubmissionStatus_MarkSuccess]')
GO

CREATE PROCEDURE [SFin].[TransactionSageSubmissionStatus_MarkSuccess]
(
      @TransactionGuid          UNIQUEIDENTIFIER
    , @TransitionGuid           UNIQUEIDENTIFIER
    , @SageOrderId              NVARCHAR(100)
    , @SageOrderNumber          NVARCHAR(100)
    , @SageTransactionReference NVARCHAR(100) = NULL
    , @ResponseStatus           NVARCHAR(50) = NULL
    , @ResponseDetail           NVARCHAR(MAX) = NULL
    , @RequestPayloadJson       NVARCHAR(MAX) = NULL
    , @ResponsePayloadJson      NVARCHAR(MAX) = NULL
    , @UpdatedByUserID          INT = -1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @StatusID BIGINT
        , @TransactionID BIGINT
        , @NowUtc DATETIME2(7) = SYSUTCDATETIME();

    BEGIN TRAN;

    SELECT
          @StatusID = s.ID
        , @TransactionID = s.TransactionID
    FROM SFin.TransactionSageSubmissionStatus AS s WITH (UPDLOCK, HOLDLOCK)
    WHERE s.TransactionGuid = @TransactionGuid
      AND s.RowStatus NOT IN (0, 254);

    IF ISNULL(@StatusID, -1) <= 0
    BEGIN
        ROLLBACK TRAN;
        THROW 60130, N'Transaction Sage submission status row not found.', 1;
    END;

    UPDATE s
    SET
          s.LastTransitionGuid = @TransitionGuid
        , s.LastOperationName = N'CreateSalesOrder'
        , s.StatusCode = N'Succeeded'
        , s.IsInProgress = 0
        , s.InProgressClaimedOnUtc = NULL
        , s.LastSucceededOnUtc = @NowUtc
        , s.SageOrderId = @SageOrderId
        , s.SageOrderNumber = @SageOrderNumber
        , s.LastError = NULL
        , s.LastErrorIsRetryable = NULL
        , s.UpdatedDateTimeUTC = @NowUtc
        , s.UpdatedByUserID = ISNULL(@UpdatedByUserID, -1)
    FROM SFin.TransactionSageSubmissionStatus AS s
    WHERE s.ID = @StatusID
      AND s.RowStatus NOT IN (0, 254);

    /*
        CYB-354 - Sage Transaction Reference Invoice Update

        When an invoice is successfully created in Sage from CymBuild,
        persist the Sage-created transaction reference back onto the
        CymBuild transaction so it is visible in Finance Transactions
        and Job Transactions.

        SageTransactionReference is populated from the outbound Sage
        posting response. Existing non-empty values are preserved when
        the caller does not supply a reference.
    */
    UPDATE t
    SET
          t.ReservedInvoiceNumber =
            CASE
                WHEN NULLIF(LTRIM(RTRIM(@SageOrderNumber)), N'') IS NOT NULL
                    THEN LTRIM(RTRIM(@SageOrderNumber))
                ELSE t.ReservedInvoiceNumber
            END
        , t.SageInvoiceNumber =
            CASE
                WHEN NULLIF(LTRIM(RTRIM(@SageOrderNumber)), N'') IS NOT NULL
                    THEN LTRIM(RTRIM(@SageOrderNumber))
                ELSE t.SageInvoiceNumber
            END
        , t.SageSalesOrderNumber =
            CASE
                WHEN NULLIF(LTRIM(RTRIM(@SageOrderNumber)), N'') IS NOT NULL
                    THEN LTRIM(RTRIM(@SageOrderNumber))
                ELSE t.SageSalesOrderNumber
            END
        , t.SageTransactionReference =
            CASE
                WHEN NULLIF(LTRIM(RTRIM(@SageTransactionReference)), N'') IS NOT NULL
                    THEN LTRIM(RTRIM(@SageTransactionReference))
                ELSE t.SageTransactionReference
            END
        , t.SageInvoiceGeneratedDateTimeUtc = @NowUtc
    FROM SFin.Transactions AS t
    WHERE t.ID = @TransactionID
      AND t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254);

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRAN;
        THROW 60131, N'Transaction could not be resolved while marking Sage submission success.', 1;
    END;

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