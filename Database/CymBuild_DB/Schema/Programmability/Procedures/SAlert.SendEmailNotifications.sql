SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SAlert].[SendEmailNotifications]	
AS
BEGIN
	SET NOCOUNT ON;

    DECLARE	@MaxID BIGINT,
			@CurrentID BIGINT = -1,
			@Recipients NVARCHAR(MAX),
			@Subject NVARCHAR(255),
			@Body NVARCHAR(MAX),
			@BodyFormat NVARCHAR(20),
			@Importance NVARCHAR(6),
			@DateTimeSent DATETIME2,
			@EmailTemplate NVARCHAR(MAX)


	SET @EmailTemplate = N'<html>
<body>
<style>
	body {
		background-image: linear-gradient(180deg, #0082de 0%, #033a67 70%);
		font-family: ''Helvetica Neue'', Helvetica, Arial, sans-serif;
	}
	
	.wrapper {
		position: relative;
		margin-left: auto;
		margin-right: auto;
		width: 90%;
	}
	
	.card-shadow {	
		padding: 0.5rem;
		text-align: center;
		background-color: #fff;
		background-clip: border-box;
		word-wrap: break-word;
		box-shadow: 0 .125rem .25rem rgba(0,0,0,.075);
		border: 1px solid rgba(0, 0, 0, .125);
		border-radius: 0.25rem;
	}
</style>
<div class="wrapper">
	<div class="card-shadow">
		<div class="card-shadow">
			<h1>New Notification from CymBuild</h1>
			<hr />
			
			<p>[[MessageText]]</p>

			<hr />
			<em>This is an automated email from the CymBuild system. Please do not reply to this email as replies are not monitored.</em>
		</div>
	</div>
</div>
</body>
</html>'


	SELECT	@MaxID = MAX(ID)
	FROM	SAlert.Notifications
	WHERE	(DateTimeSent IS NULL)

	WHILE (@CurrentID < @MaxID)
	BEGIN 
		SELECT	TOP(1) @CurrentID = ID,
				@Recipients = Recipients,
				@Subject = Subject,
				@Body = Body,
				@BodyFormat = BodyFormat,
				@Importance = Importance,
				@DateTimeSent = DateTimeSent
		FROM	SAlert.Notifications
		WHERE	(ID > @CurrentID)
		ORDER BY ID

		IF (@DateTimeSent IS NULL)
		BEGIN 

			IF (@BodyFormat = N'TEXT')
			BEGIN 
				SET @Body = REPLACE(@EmailTemplate, N'[[MessageText]]', @Body)

				SET @BodyFormat = N'HTML'

			END
			
			EXEC msdb.dbo.sp_send_dbmail
				@profile_name = N'exchange.socotec.co.uk',
				@recipients = @Recipients,
				@from_address = N'no-reply@socotec.co.uk',
				@subject = @Subject,
				@body = @body,
				@body_format = @BodyFormat,
				@importance = @Importance

			UPDATE	SAlert.Notifications 
			SET		DateTimeSent = GETUTCDATE()
			WHERE	(ID = @CurrentID)
		END
	END
END
GO