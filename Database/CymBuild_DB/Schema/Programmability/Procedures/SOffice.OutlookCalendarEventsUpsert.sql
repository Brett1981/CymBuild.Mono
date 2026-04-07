SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SOffice].[OutlookCalendarEventsUpsert]
	(	@TargetObjectGuid UNIQUEIDENTIFIER,
		@Mailbox NVARCHAR(250),
		@ExchangeImmutableID NVARCHAR(250),
		@Title NVARCHAR(2000),
		@StartDateTime DATETIME2,
		@EndDateTime DATETIME2,
		@IsAllDay BIT,
		@Recurrence NVARCHAR(MAX),
		@LastUpdateSource nvarchar(1),
		@Guid UNIQUEIDENTIFIER
	)
AS
BEGIN
	DECLARE @TargetObjectId				 INT,
			@OEMailboxID				 INT

	SELECT	@TargetObjectId = ID
	FROM	SOffice.TargetObjects
	WHERE	(Guid = @TargetObjectGuid);

	SELECT	@OEMailboxID = ID
	FROM	SOffice.OutlookEmailMailboxes
	WHERE	(Name = @Mailbox);

	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT	SOffice.OutlookEmailMailboxes
			 (Guid, RowStatus, Name)
		VALUES
			 (
				 NEWID (),	-- Guid - uniqueidentifier
				 1,			-- RowStatus - tinyint
				 @Mailbox	-- Name - nvarchar(250)
			 );

		SELECT	@OEMailboxID = SCOPE_IDENTITY ();
	END;

	IF (NOT EXISTS
	 (
		 SELECT 1
		 FROM	SOffice.OutlookCalendarEvents
		 WHERE	(Guid = @Guid)
	 )
	   )
	BEGIN
		INSERT	SOffice.OutlookCalendarEvents
			 (Guid,
			  RowStatus,
			  TargetObjectID,
			  OutlookEmailMailboxID,
			  ExchangeImmutableID,
			  Title,
			  StartDateTime,
			  EndDateTime,
			  IsAllDay,
			  Recurrence,
			  LastUpdateSource)
		VALUES
			 (
				 @Guid,	-- Guid - uniqueidentifier
				 1,	-- RowStatus - tinyint
				 @TargetObjectId,	-- TargetObjectID - bigint
				 @OEMailboxID,	-- OutlookEmailMailboxID - int
				 @ExchangeImmutableID,	-- ExchangeImmutableID - nvarchar(250)
				 @Title,	-- Title - nvarchar(2000)
				 @StartDateTime,	-- StartDateTime - datetime2(7)
				 @EndDateTime,	-- EndDateTime - datetime2(7)
				 @IsAllDay,	-- IsAllDay - bit
				 @Recurrence,	-- Recurrence - nvarchar(max)
				 @LastUpdateSource
			 )
	END;
	ELSE
	BEGIN
		UPDATE	SOffice.OutlookCalendarEvents
		SET		TargetObjectID = @TargetObjectID,
				OutlookEmailMailboxID = @OEMailboxID,
				ExchangeImmutableID = @ExchangeImmutableID,
				Title = @Title,
				StartDateTime = @StartDateTime,
				EndDateTime = @EndDateTime,
				IsAllDay = @IsAllDay,
				Recurrence = @Recurrence,
				LastUpdateSource = @LastUpdateSource
		WHERE	(Guid = @Guid);
	END;
END;
GO