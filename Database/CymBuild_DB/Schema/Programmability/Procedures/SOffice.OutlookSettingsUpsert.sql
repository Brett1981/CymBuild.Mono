SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SOffice].[OutlookSettingsUpsert]')
GO
CREATE PROCEDURE [SOffice].[OutlookSettingsUpsert]
    (
	   @SettingsJSON NVARCHAR(MAX),
	   @UserEmail NVARCHAR(100)
    )
AS
BEGIN
	
	DECLARE @UserId INT;

	SELECT @UserId = ID
	FROM SCore.Identities
	WHERE EmailAddress = @UserEmail;

	 UPDATE SCore.UserPreferences
	 SET OutlookSettings = @SettingsJSON
	 WHERE ID = @UserId

END;
GO