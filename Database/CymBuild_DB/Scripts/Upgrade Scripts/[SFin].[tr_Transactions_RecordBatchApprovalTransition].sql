PRINT (N'Create trigger [SFin].[tr_Transactions_RecordBatchApprovalTransition] on table [SFin].[Transactions]')
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

    DECLARE
        @TransactionID BIGINT,
        @TransactionGuid UNIQUEIDENTIFIER,
        @SurveyorUserId INT,
        @CreatedByUserId INT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            i.ID,
            i.Guid,
            i.SurveyorUserId,
            COALESCE(CONVERT(INT, SESSION_CONTEXT(N'user_id')), i.CreatedByUserId, -1) AS CreatedByUserId
        FROM inserted AS i
        INNER JOIN deleted AS d
            ON d.ID = i.ID
        WHERE i.RowStatus <> 0
          AND i.RowStatus <> 254
          AND d.RowStatus <> 0
          AND d.RowStatus <> 254
          AND ISNULL(d.Batched, 0) = 1
          AND ISNULL(i.Batched, 0) = 0;

    OPEN cur;

    FETCH NEXT FROM cur INTO
        @TransactionID,
        @TransactionGuid,
        @SurveyorUserId,
        @CreatedByUserId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SFin.TransactionSageSubmission_EnsureQueued
             @TransactionID = @TransactionID,
             @TransactionGuid = @TransactionGuid,
             @CreatedByUserId = @CreatedByUserId,
             @SurveyorUserId = @SurveyorUserId,
             @Comment = N'Finance approval detected from Batched 1 to 0.',
             @SuppressResult = 1;

        FETCH NEXT FROM cur INTO
            @TransactionID,
            @TransactionGuid,
            @SurveyorUserId,
            @CreatedByUserId;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO
