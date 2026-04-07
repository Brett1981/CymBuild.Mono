USE [CymBuild_Dev]
GO

CREATE OR ALTER TRIGGER [SFin].[tr_Transactions_RecordBatchApprovalTransition]
ON [SFin].[Transactions]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF (ISNULL(CONVERT(INT, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
        RETURN;

    IF NOT UPDATE(Batched)
        RETURN;

    ;WITH Changed AS
    (
        SELECT
            i.ID,
            i.Guid,
            d.Batched AS OldBatched,
            i.Batched AS NewBatched,
            i.RowVersion AS SourceTransactionRowVersion,
            i.SurveyorUserId,
            COALESCE(CONVERT(INT, SESSION_CONTEXT(N'user_id')), i.CreatedByUserId, -1) AS CreatedByUserId
        FROM inserted AS i
        INNER JOIN deleted AS d
            ON d.ID = i.ID
        WHERE
                i.RowStatus NOT IN (0, 254)
            AND d.RowStatus NOT IN (0, 254)
            AND ISNULL(d.Batched, 0) = 1
            AND ISNULL(i.Batched, 0) = 0
    )
    SELECT *
    INTO #Changed
    FROM Changed;

    DECLARE
        @TransactionID BIGINT,
        @TransactionGuid UNIQUEIDENTIFIER,
        @OldBatched BIT,
        @NewBatched BIT,
        @SourceTransactionRowVersion BINARY(8),
        @SurveyorUserId INT,
        @CreatedByUserId INT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            TransactionID = ID,
            TransactionGuid = Guid,
            OldBatched,
            NewBatched,
            SourceTransactionRowVersion,
            SurveyorUserId,
            CreatedByUserId
        FROM #Changed;

    OPEN cur;

    FETCH NEXT FROM cur INTO
        @TransactionID,
        @TransactionGuid,
        @OldBatched,
        @NewBatched,
        @SourceTransactionRowVersion,
        @SurveyorUserId,
        @CreatedByUserId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC [SFin].[TransactionBatchTransition_Insert]
             @TransactionID               = @TransactionID,
             @TransactionGuid             = @TransactionGuid,
             @OldBatched                  = @OldBatched,
             @NewBatched                  = @NewBatched,
             @CreatedByUserId             = @CreatedByUserId,
             @SurveyorUserId              = @SurveyorUserId,
             @Comment                     = N'Finance approval detected from Batched 1 to 0.',
             @IsImported                  = 0,
             @SourceTransactionRowVersion = @SourceTransactionRowVersion;

        FETCH NEXT FROM cur INTO
            @TransactionID,
            @TransactionGuid,
            @OldBatched,
            @NewBatched,
            @SourceTransactionRowVersion,
            @SurveyorUserId,
            @CreatedByUserId;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO 