USE [CymBuild_Dev]
GO

CREATE OR ALTER PROCEDURE [SFin].[TransactionBatchTransition_Insert]
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

    BEGIN TRY
        BEGIN TRAN;

        IF (@OldBatched <> 1 OR @NewBatched <> 0)
        BEGIN
            COMMIT TRAN;
            RETURN;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM SFin.Transactions AS t
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
            FROM SFin.TransactionBatchTransitions AS x
            WHERE   x.TransactionGuid = @TransactionGuid
                AND x.SourceTransactionRowVersion = @SourceTransactionRowVersion
                AND x.RowStatus NOT IN (0, 254)
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
            @SurveyorUserId,
            @Comment,
            ISNULL(@IsImported, 0),
            @SourceTransactionRowVersion
        );

        EXEC [SFin].[TransactionBatchTransition_EnqueueOutbox]
             @TransactionBatchTransitionGuid = @TransitionGuid;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        THROW;
    END CATCH
END;
GO