SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[AccountContactsUpsert]
(
    @AccountGuid UNIQUEIDENTIFIER,
	@ContactGuid UNIQUEIDENTIFIER,
	@PrimaryAccountAddressGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @AccountID INT,
			@ContactID INT,
			@PrimaryAccountAddressID INT

    SELECT  @AccountID = ID 
    FROM    SCrm.Accounts
    WHERE   ([Guid] = @AccountGuid)

	SELECT  @ContactID = ID 
    FROM    SCrm.Contacts
    WHERE   ([Guid] = @ContactGuid)

	SELECT  @PrimaryAccountAddressID = ID 
    FROM    SCrm.AccountAddresses
    WHERE   ([Guid] = @PrimaryAccountAddressGuid)

	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SCrm',				-- nvarchar(255)
							@ObjectName = N'AccountContacts',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT SCrm.AccountContacts
			 (RowStatus, Guid, AccountID, ContactID, PrimaryAccountAddressID)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @AccountID,	-- AccountID - int
				 @ContactID,	-- ContactID - int
				 @PrimaryAccountAddressID
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SCrm.AccountContacts
        SET     AccountID = @AccountID,
				ContactID = @ContactID,
				PrimaryAccountAddressID = @PrimaryAccountAddressID
        WHERE   ([Guid] = @Guid)
    END
END
GO