SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[CreateUserSession]
	(
		@UserEmail		NVARCHAR(250),
		@ApplicationUrl NVARCHAR(500) = N'https://bre.socotec.co.uk:9602'
	)
AS
	BEGIN
		DECLARE @UserID	  INT,
				@UserGuid UNIQUEIDENTIFIER

		SELECT
				@UserID	  = ID,
				@UserGuid = Guid
		FROM
				SCore.Identities
		WHERE
				(EmailAddress = @UserEmail)

		IF (@@rowcount < 1)
		BEGIN 
			DECLARE @MissingUserMessage NVARCHAR(4000) = N'No user record exists for ' + @UserEmail
			;THROW 60000, @MissingUserMessage, 1
		END

		EXECUTE sys.sp_set_session_context
			@key   = N'user_id',
			@value = @UserID;

		EXECUTE sys.sp_set_session_context
			@key   = N'user_guid',
			@value = @UserGuid;

		EXECUTE sys.sp_set_session_context
			@key   = N'application_url',
			@value = @ApplicationUrl;

	END
GO