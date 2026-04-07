SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE PROCEDURE [SFin].[TransactionAllocationsUpsert]
(
    @SourceTransactionGuid UNIQUEIDENTIFIER,
	@TargetTransactionGuid UNIQUEIDENTIFIER,
	@AllocatedValue DECIMAL(9,2),
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @SourceTransactionID INT,
			@TargetTransactionID INT

    SELECT  @SourceTransactionID = ID 
    FROM    SFin.Transactions
    WHERE   ([Guid] = @SourceTransactionGuid)

	SELECT  @TargetTransactionID = ID 
    FROM    SFin.Transactions
    WHERE   ([Guid] = @TargetTransactionGuid)


    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SFin',				-- nvarchar(255)
							@ObjectName = N'TransactionAllocations',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT SFin.TransactionAllocations
			 (RowStatus, Guid, SourceTransactionID, TargetTransactionID, AllocatedAmount)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @SourceTransactionID,	-- SourceTransactionID - bigint
				 @TargetTransactionID,	-- TargetTransactionID - bigint
				 @AllocatedValue	-- AllocatedAmount - decimal(9, 2)
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SFin.TransactionAllocations
        SET     SourceTransactionID = @SourceTransactionID,
				TargetTransactionID = @TargetTransactionID,
				AllocatedAmount = @AllocatedValue
        WHERE   ([Guid] = @Guid)
    END
END
GO