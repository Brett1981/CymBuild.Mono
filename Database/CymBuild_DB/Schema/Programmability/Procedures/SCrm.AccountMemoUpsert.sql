SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO





CREATE PROCEDURE [SCrm].[AccountMemoUpsert]
(
    @AccountGuid UNIQUEIDENTIFIER,
	@Memo NVARCHAR(MAX),
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @AccountID INT

    SELECT  @AccountID = ID 
    FROM    SCrm.Accounts
    WHERE   ([Guid] = @AccountGuid)

	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SCrm',				-- nvarchar(255)
							@ObjectName = N'AccountMemos',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT SCrm.AccountMemos
			 (RowStatus, Guid, AccountID, Memo)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @AccountID,	-- AccountID - int
				 @Memo	-- AddressID - int
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SCrm.AccountMemos
        SET     AccountID = @AccountID,
				Memo = @Memo
        WHERE   ([Guid] = @Guid)
    END
END
GO