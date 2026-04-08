CREATE OR ALTER PROCEDURE [SFin].[SageInbound_ReconcileAllocations]
(
    @ExternalAllocationID BIGINT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @SourceExternalTransactionID BIGINT,
        @TargetExternalTransactionID BIGINT,
        @AllocatedAmount            DECIMAL(18,2),
        @MatchedSourceTransactionID BIGINT = -1,
        @MatchedTargetTransactionID BIGINT = -1;

    SELECT
        @SourceExternalTransactionID = ext.SourceExternalTransactionID,
        @TargetExternalTransactionID = ext.TargetExternalTransactionID,
        @AllocatedAmount             = ext.AllocatedAmount
    FROM SFin.SageExternalAllocations ext
    WHERE ext.ID = @ExternalAllocationID
      AND ext.RowStatus NOT IN (0,254);

    IF @SourceExternalTransactionID IS NULL
    BEGIN
        RAISERROR('Sage external allocation not found.', 16, 1);
        RETURN;
    END;

    SELECT
        @MatchedSourceTransactionID = src.MatchedTransactionID
    FROM SFin.SageExternalTransactions src
    WHERE src.ID = @SourceExternalTransactionID
      AND src.RowStatus NOT IN (0,254);

    SELECT
        @MatchedTargetTransactionID = tgt.MatchedTransactionID
    FROM SFin.SageExternalTransactions tgt
    WHERE tgt.ID = @TargetExternalTransactionID
      AND tgt.RowStatus NOT IN (0,254);

    UPDATE ext
    SET
        MatchedSourceTransactionID = ISNULL(@MatchedSourceTransactionID, -1),
        MatchedTargetTransactionID = ISNULL(@MatchedTargetTransactionID, -1),
        UpdatedByUserID            = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC         = GETUTCDATE()
    FROM SFin.SageExternalAllocations ext
    WHERE ext.ID = @ExternalAllocationID
      AND ext.RowStatus NOT IN (0,254);

    IF
    (
        ISNULL(@MatchedSourceTransactionID, -1) > 0
        AND ISNULL(@MatchedTargetTransactionID, -1) > 0
        AND @AllocatedAmount IS NOT NULL
        AND NOT EXISTS
        (
            SELECT 1
            FROM SFin.TransactionAllocations ta
            WHERE ta.SourceTransactionID = @MatchedSourceTransactionID
              AND ta.TargetTransactionID = @MatchedTargetTransactionID
              AND ta.AllocatedAmount     = @AllocatedAmount
              AND ta.RowStatus NOT IN (0,254)
        )
    )
    BEGIN
        DECLARE @NewAllocationGuid UNIQUEIDENTIFIER = NEWID();
        DECLARE @IsInsert BIT;

        EXEC SCore.UpsertDataObject
             @Guid       = @NewAllocationGuid,
             @SchemeName = N'SFin',
             @ObjectName = N'TransactionAllocations',
             @IsInsert   = @IsInsert OUTPUT;

        INSERT INTO SFin.TransactionAllocations
        (
            RowStatus,
            Guid,
            SourceTransactionID,
            TargetTransactionID,
            AllocatedAmount
        )
        VALUES
        (
            1,
            @NewAllocationGuid,
            @MatchedSourceTransactionID,
            @MatchedTargetTransactionID,
            @AllocatedAmount
        );
    END;

    SELECT
        @ExternalAllocationID AS ExternalAllocationID,
        CAST
        (
            CASE
                WHEN ISNULL(@MatchedSourceTransactionID, -1) > 0
                 AND ISNULL(@MatchedTargetTransactionID, -1) > 0
                THEN 1 ELSE 0
            END
            AS BIT
        ) AS IsFullyMatched,
        ISNULL(@MatchedSourceTransactionID, -1) AS MatchedSourceTransactionID,
        ISNULL(@MatchedTargetTransactionID, -1) AS MatchedTargetTransactionID;
END;
GO