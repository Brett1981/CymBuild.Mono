SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionSageSubmissionStatus_MarkSuccess]')
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
    , @SageDataset              NVARCHAR(30) = 'group'
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @StatusID BIGINT
        , @TransactionID BIGINT
        , @JobID INT
        , @SageAccountReference NVARCHAR(100)
        , @SageDocumentNo NVARCHAR(100)
        , @ResolvedSageDataset NVARCHAR(30)
        , @NowUtc DATETIME2(7) = SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRAN;

        SELECT
              @StatusID = s.ID
            , @TransactionID = s.TransactionID
        FROM SFin.TransactionSageSubmissionStatus AS s WITH (UPDLOCK, HOLDLOCK)
        WHERE s.TransactionGuid = @TransactionGuid
          AND s.RowStatus NOT IN (0, 254);

        IF ISNULL(@StatusID, -1) <= 0
        BEGIN
            ;THROW 60130, N'Transaction Sage submission status row not found.', 1;
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
            ;THROW 60131, N'Transaction could not be resolved while marking Sage submission success.', 1;
        END;

        SELECT
              @JobID = NULLIF(t.JobID, -1)
            , @SageAccountReference = acc.Code
            , @SageDocumentNo =
                COALESCE
                (
                    NULLIF(LTRIM(RTRIM(@SageOrderNumber)), N''),
                    NULLIF(LTRIM(RTRIM(t.SageSalesOrderNumber)), N''),
                    NULLIF(LTRIM(RTRIM(t.SageInvoiceNumber)), N''),
                    NULLIF(LTRIM(RTRIM(t.ReservedInvoiceNumber)), N''),
                    NULLIF(LTRIM(RTRIM(t.Number)), N'')
                )
        FROM SFin.Transactions AS t
        JOIN SCrm.Accounts AS acc
            ON acc.ID = t.AccountID
           AND acc.RowStatus NOT IN (0,254)
        WHERE t.ID = @TransactionID
          AND t.Guid = @TransactionGuid
          AND t.RowStatus NOT IN (0,254);

        ---------------------------------------------------------------------
        -- CYB-414
        -- Resolve the Sage dataset for inbound payment sync.
        --
        -- Preferred order:
        -- 1. Optional caller-supplied dataset.
        -- 2. Existing inbound status row for this transaction.
        -- 3. Latest successful row for the same Sage account.
        -- 4. Latest successful row overall.
        -- 5. Current CymBuild single-dataset default used by existing rows.
        ---------------------------------------------------------------------
        SELECT
            @ResolvedSageDataset =
                COALESCE
                (
                    NULLIF(LTRIM(RTRIM(@SageDataset)), N''),
                    NULLIF(LTRIM(RTRIM(existingInbound.SageDataset)), N''),
                    NULLIF(LTRIM(RTRIM(accountDataset.SageDataset)), N''),
                    NULLIF(LTRIM(RTRIM(anyDataset.SageDataset)), N''),
                    N'group'
                )
        FROM
        (
            SELECT 1 AS DummyValue
        ) AS anchor
        OUTER APPLY
        (
            SELECT TOP (1)
                s.SageDataset
            FROM SFin.SageInboundDocumentStatus AS s
            WHERE s.RowStatus NOT IN (0,254)
              AND
              (
                    s.TransactionID = @TransactionID
                 OR s.CymBuildDocumentGuid = @TransactionGuid
              )
              AND NULLIF(LTRIM(RTRIM(s.SageDataset)), N'') IS NOT NULL
            ORDER BY
                s.ID DESC
        ) AS existingInbound
        OUTER APPLY
        (
            SELECT TOP (1)
                s.SageDataset
            FROM SFin.SageInboundDocumentStatus AS s
            WHERE s.RowStatus NOT IN (0,254)
              AND s.StatusCode = N'Succeeded'
              AND NULLIF(LTRIM(RTRIM(s.SageDataset)), N'') IS NOT NULL
              AND NULLIF(LTRIM(RTRIM(s.SageAccountReference)), N'') = NULLIF(LTRIM(RTRIM(@SageAccountReference)), N'')
            ORDER BY
                ISNULL(s.LastSucceededOnUtc, s.UpdatedDateTimeUTC) DESC,
                s.ID DESC
        ) AS accountDataset
        OUTER APPLY
        (
            SELECT TOP (1)
                s.SageDataset
            FROM SFin.SageInboundDocumentStatus AS s
            WHERE s.RowStatus NOT IN (0,254)
              AND s.StatusCode = N'Succeeded'
              AND NULLIF(LTRIM(RTRIM(s.SageDataset)), N'') IS NOT NULL
            ORDER BY
                ISNULL(s.LastSucceededOnUtc, s.UpdatedDateTimeUTC) DESC,
                s.ID DESC
        ) AS anyDataset;

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
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRAN;
        END;

        THROW;
    END CATCH;

    -------------------------------------------------------------------------
    -- CYB-414
    -- Enqueue inbound payment/receipt diagnostics after the outbound Sage
    -- success has been safely committed.
    --
    -- This is best-effort only. A downstream inbound enqueue issue must never
    -- roll back or demote the confirmed outbound Sage success.
    -------------------------------------------------------------------------
    BEGIN TRY
        EXEC SFin.SageInboundPaymentSync_Enqueue
             @CymBuildDocumentGuid = @TransactionGuid,
             @CymBuildDocumentID = @TransactionID,
             @TransactionID = @TransactionID,
             @JobID = @JobID,
             @SageDataset = @ResolvedSageDataset,
             @SageAccountReference = @SageAccountReference,
             @SageDocumentNo = @SageDocumentNo,
             @ForceRequeue = 0;
    END TRY
    BEGIN CATCH
        DECLARE @InboundEnqueueError NVARCHAR(MAX) = ERROR_MESSAGE();

        PRINT N'CYB-414 warning: outbound Sage submission succeeded, but inbound diagnostics enqueue failed. Outbound success retained. Error: '
            + ISNULL(@InboundEnqueueError, N'Unknown error.');
    END CATCH;
END
GO