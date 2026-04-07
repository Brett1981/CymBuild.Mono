SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCrm].[ai_account_upsert]')
GO
CREATE PROCEDURE [SCrm].[ai_account_upsert]
(
	@name nvarchar(50),
	@address_line_1 nvarchar(50),
	@address_line_2 nvarchar(50),
	@town nvarchar(50),
	@county nvarchar(50),
	@post_code nvarchar(20)
)
AS
BEGIN 
	DECLARE @ID INT,
			@AddressID int	
	
	SELECT @ID = ID
	FROM SCrm.Accounts 
	WHERE name = @name

		
	IF (@ID IS NOT NULL)
	BEGIN 
		return @ID
	END
	ELSE
	BEGIN 
		INSERT	SCrm.Accounts 
		(
			Guid,
			Name,
			RowStatus
		)
		values
		(
			NEWID(),
			@name,
			1
		)

		SELECT	@ID = SCOPE_IDENTITY()

		INSERT	SCrm.Addresses
		(
			Guid,
			RowStatus,
			AddressLine1,
			AddressLine2,
			AddressLine3,
			Town, 
			Number,
			Postcode,
			CountyID
		)
		values
		(
			newid(),
			1,
			@address_line_2,
			N'',
			N'',
			@town,
			@address_line_1,
			@post_code,
			(SELECT ID FROM SCrm.Counties WHERE Name = @county)
		)

		SELECT	@AddressID = SCOPE_IDENTITY()

		INSERT	SCrm.AccountAddresses
		(Guid, RowStatus, AccountID, AddressID)
		VALUES (NEWID(), 1, @ID, @AddressID)

	END

END
GO