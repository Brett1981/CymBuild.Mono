SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionBatchTransition_Insert]')
GO
PRINT (N'Create procedure [SFin].[TransactionBatchTransition_Insert]')
GO

CREATE PROCEDURE [SFin].[TransactionBatchTransition_Insert]
(
    @TransactionID               BIGINT,
    @TransactionGuid             UNIQUEIDENTIFIER,
    @OldBatched                  BIT,
    @NewBatched                  BIT,
    @CreatedByUserId             INT,
    @SurveyorUserId              INT = -1,
    @Comment                     NVARCHAR(MAX) = '',
    @IsImported                  BIT = 0,
    @SourceTransactionRowVersion BINARY(8)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TransitionGuid UNIQUEIDENTIFIER = NEWID();
    DECLARE @IsInsert BIT;
    DECLARE @AppLockResult INT;
    DECLARE @AppLockResource NVARCHAR(255);

    BEGIN TRY
        BEGIN TRAN;

        IF (ISNULL(@OldBatched, 0) <> 1 OR ISNULL(@NewBatched, 1) <> 0)
        BEGIN
            COMMIT TRAN;
            RETURN;
        END;

        SET @AppLockResource = CONCAT
        (
            N'SFin.TransactionBatchTransition:',
            CONVERT(NVARCHAR(36), @TransactionGuid)
        );

        EXEC @AppLockResult = sys.sp_getapplock
             @Resource = @AppLockResource,
             @LockMode = N'Exclusive',
             @LockOwner = N'Transaction',
             @LockTimeout = 10000;

        IF ISNULL(@AppLockResult, -999) < 0
        BEGIN
            ;THROW 70002, N'TransactionBatchTransition_Insert: could not acquire transaction approval idempotency lock.', 1;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM SFin.Transactions AS t WITH (UPDLOCK, HOLDLOCK)
            WHERE   t.ID = @TransactionID
                AND t.Guid = @TransactionGuid
                AND t.RowStatus NOT IN (0, 254)
                AND t.Batched = 0
        )
        BEGIN
            ;THROW 70001, N'TransactionBatchTransition_Insert: transaction not found in expected approved state.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM SFin.TransactionBatchTransitions AS x WITH (UPDLOCK, HOLDLOCK)
            WHERE   x.TransactionGuid = @TransactionGuid
                AND x.SourceTransactionRowVersion = @SourceTransactionRowVersion
                AND x.RowStatus NOT IN (0, 254)
        )
        BEGIN
            COMMIT TRAN;
            RETURN;
        END;

        -------------------------------------------------------------------------
        -- CYB-414
        -- If the transaction already has confirmed Sage success/reference, do not
        -- create another approval transition or enqueue another Sage submission.
        -------------------------------------------------------------------------
        IF EXISTS
        (
            SELECT 1
            FROM SFin.Transactions AS t WITH (UPDLOCK, HOLDLOCK)
            LEFT JOIN SFin.TransactionSageSubmissionStatus AS s WITH (UPDLOCK, HOLDLOCK)
                ON s.TransactionGuid = t.Guid
               AND s.RowStatus NOT IN (0, 254)
            WHERE t.ID = @TransactionID
              AND t.Guid = @TransactionGuid
              AND t.RowStatus NOT IN (0, 254)
              AND
              (
                    s.StatusCode = N'Succeeded'
                 OR s.LastSucceededOnUtc IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(ISNULL(s.SageOrderId, N''))), N'') IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(ISNULL(s.SageOrderNumber, N''))), N'') IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(ISNULL(t.SageTransactionReference, N''))), N'') IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(ISNULL(t.SageInvoiceNumber, N''))), N'') IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(ISNULL(t.SageSalesOrderNumber, N''))), N'') IS NOT NULL
              )
        )
        BEGIN
            COMMIT TRAN;
            RETURN;
        END;

        -------------------------------------------------------------------------
        -- CYB-414
        -- If an unpublished Sage submission event already exists for this
        -- transaction, do not create another transition/outbox event. The existing
        -- outbox row should be processed/retried by the worker.
        -------------------------------------------------------------------------
        IF EXISTS
        (
            SELECT 1
            FROM SCore.IntegrationOutbox AS io WITH (UPDLOCK, HOLDLOCK)
            WHERE io.RowStatus NOT IN (0, 254)
              AND io.EventType = N'TransactionApprovedForSageSubmission'
              AND io.PublishedOnUtc IS NULL
              AND ISJSON(io.PayloadJson) = 1
              AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(io.PayloadJson, '$.transactionGuid')) = @TransactionGuid
        )
        BEGIN
            COMMIT TRAN;
            RETURN;
        END;

        EXEC SCore.UpsertDataObject
             @Guid       = @TransitionGuid,
             @SchemeName = N'SFin',
             @ObjectName = N'TransactionBatchTransitions',
             @IsInsert   = @IsInsert OUTPUT;

        INSERT INTO SFin.TransactionBatchTransitions
        (
            RowStatus,
            Guid,
            TransactionID,
            TransactionGuid,
            OldBatched,
            NewBatched,
            DateTimeUTC,
            CreatedByUserId,
            SurveyorUserId,
            Comment,
            IsImported,
            SourceTransactionRowVersion
        )
        VALUES
        (
            1,
            @TransitionGuid,
            @TransactionID,
            @TransactionGuid,
            @OldBatched,
            @NewBatched,
            SYSUTCDATETIME(),
            ISNULL(@CreatedByUserId, -1),
            ISNULL(@SurveyorUserId, -1),
            ISNULL(@Comment, N''),
            ISNULL(@IsImported, 0),
            @SourceTransactionRowVersion
        );

        EXEC [SFin].[TransactionBatchTransition_EnqueueOutbox]
             @TransactionBatchTransitionGuid = @TransitionGuid;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRAN;
        END;

        THROW;
    END CATCH
END;
GO