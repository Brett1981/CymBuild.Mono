SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[AccountAddressesUpsert]
(
    @AccountGuid UNIQUEIDENTIFIER,
	@AddressGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @AccountID INT,
			@AddressID INT

    SELECT  @AccountID = ID 
    FROM    SCrm.Accounts
    WHERE   ([Guid] = @AccountGuid)

	SELECT  @AddressID = ID 
    FROM    SCrm.Addresses
    WHERE   ([Guid] = @AddressGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SCrm',				-- nvarchar(255)
							@ObjectName = N'AccountAddresses',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT,	-- bit
							@IncludeDefaultSecurity = 0

    IF (@IsInsert = 1)
    BEGIN
		INSERT SCrm.AccountAddresses
			 (RowStatus, Guid, AccountID, AddressID)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @AccountID,	-- AccountID - int
				 @AddressID	-- AddressID - int
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SCrm.AccountAddresses
        SET     AccountID = @AccountID,
				AddressID = @AddressID
        WHERE   ([Guid] = @Guid)
    END
END
GO