CREATE OR ALTER PROCEDURE [SFin].[SageExternalAllocation_Upsert]
(
    @SourceExternalTransactionID BIGINT,
    @TargetExternalTransactionID BIGINT,
    @AllocatedAmount            DECIMAL(18,2),
    @AllocationDate             DATE = NULL,
    @MatchedSourceTransactionID BIGINT = -1,
    @MatchedTargetTransactionID BIGINT = -1,
    @SourceHash                 NVARCHAR(128),
    @RawPayloadJson             NVARCHAR(MAX) = NULL,
    @Guid                       UNIQUEIDENTIFIER OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2(7) = GETUTCDATE();

    IF EXISTS
    (
        SELECT 1
        FROM SFin.SageExternalAllocations ext
        WHERE ext.SourceExternalTransactionID = @SourceExternalTransactionID
          AND ext.TargetExternalTransactionID = @TargetExternalTransactionID
          AND ext.AllocatedAmount             = @AllocatedAmount
          AND ISNULL(ext.AllocationDate, '19000101') = ISNULL(@AllocationDate, '19000101')
          AND ext.SourceHash                  = @SourceHash
          AND ext.RowStatus NOT IN (0,254)
    )
    BEGIN
        SELECT
            @Guid = ext.Guid
        FROM SFin.SageExternalAllocations ext
        WHERE ext.SourceExternalTransactionID = @SourceExternalTransactionID
          AND ext.TargetExternalTransactionID = @TargetExternalTransactionID
          AND ext.AllocatedAmount             = @AllocatedAmount
          AND ISNULL(ext.AllocationDate, '19000101') = ISNULL(@AllocationDate, '19000101')
          AND ext.SourceHash                  = @SourceHash
          AND ext.RowStatus NOT IN (0,254);

        UPDATE ext
        SET
            MatchedSourceTransactionID = @MatchedSourceTransactionID,
            MatchedTargetTransactionID = @MatchedTargetTransactionID,
            LastSeenOnUtc              = @NowUtc,
            RawPayloadJson             = @RawPayloadJson,
            UpdatedByUserID            = SCore.GetCurrentUserId(),
            UpdatedDateTimeUTC         = @NowUtc
        FROM SFin.SageExternalAllocations ext
        WHERE ext.Guid = @Guid;

        RETURN;
    END;

    IF (@Guid IS NULL OR @Guid = '00000000-0000-0000-0000-000000000000')
    BEGIN
        SET @Guid = NEWID();
    END;

    DECLARE @IsInsert BIT;

    EXEC SCore.UpsertDataObject
         @Guid       = @Guid,
         @SchemeName = N'SFin',
         @ObjectName = N'SageExternalAllocations',
         @IsInsert   = @IsInsert OUTPUT;

    INSERT INTO SFin.SageExternalAllocations
    (
        RowStatus,
        Guid,
        SourceExternalTransactionID,
        TargetExternalTransactionID,
        AllocatedAmount,
        AllocationDate,
        MatchedSourceTransactionID,
        MatchedTargetTransactionID,
        SourceHash,
        LastSeenOnUtc,
        RawPayloadJson,
        CreatedByUserID,
        CreatedDateTimeUTC,
        UpdatedByUserID,
        UpdatedDateTimeUTC
    )
    VALUES
    (
        1,
        @Guid,
        @SourceExternalTransactionID,
        @TargetExternalTransactionID,
        @AllocatedAmount,
        @AllocationDate,
        @MatchedSourceTransactionID,
        @MatchedTargetTransactionID,
        @SourceHash,
        @NowUtc,
        @RawPayloadJson,
        SCore.GetCurrentUserId(),
        @NowUtc,
        SCore.GetCurrentUserId(),
        @NowUtc
    );
END;
GO