SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE PROCEDURE [SFin].[FinanceMemoUpsert]
(
    @AccountGuid UNIQUEIDENTIFIER,
	@JobGuid UNIQUEIDENTIFIER,
	@TransactionGuid UNIQUEIDENTIFIER,
	@Memo NVARCHAR(MAX),
	@UserGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @AccountID INT = ((-1)),
			@JobID INT = ((-1)),
			@TransactionId INT = ((-1)),
			@UserId INT = ((-1))

    SELECT  @AccountID = ID 
    FROM    SCrm.Accounts
    WHERE   ([Guid] = @AccountGuid)

	SELECT  @JobID = ID 
    FROM    SJob.Jobs
    WHERE   ([Guid] = @JobGuid)

	SELECT  @TransactionId = ID 
    FROM    SFin.Transactions
    WHERE   ([Guid] = @TransactionGuid)

	SELECT  @UserId = ID 
    FROM    SCore.Identities
    WHERE   ([Guid] = @UserGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SFin',				-- nvarchar(255)
							@ObjectName = N'FinanceMemo',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT SFin.FinanceMemo
			 (RowStatus, Guid, TransactionID, AccountID, JobID, Memo, CreatedDateTimeUTC, CreatedByUserId)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @TransactionId,	-- TransactionID - bigint
				 @AccountID,	-- AccountID - int
				 @JobID,	-- JobID - int
				 @Memo,	-- Memo - nvarchar(max)
				 GETUTCDATE(),	-- CreatedDateTimeUTC - datetime2(7)
				 @UserId	-- CreatedByUserId - int
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SFin.FinanceMemo
        SET     Memo = @Memo,
				JobID = @JobID,
				AccountID = @AccountID,
				TransactionID = @TransactionId
        WHERE   ([Guid] = @Guid)
    END


END
GO