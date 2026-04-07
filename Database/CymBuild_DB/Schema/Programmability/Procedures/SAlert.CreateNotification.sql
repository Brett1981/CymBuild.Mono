SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SAlert].[CreateNotification]	
(
	@Recipients NVARCHAR(MAX),
	@Subject NVARCHAR(255),
	@Body NVARCHAR(MAX),
	@BodyFormat NVARCHAR(20),
	@Importance NVARCHAR(6)
)
AS
BEGIN
	SET NOCOUNT ON;

	INSERT	SAlert.Notifications
		 (RowStatus, Guid, Recipients, Subject, Body, BodyFormat, Importance, DateTimeSent)
	VALUES
		 (
			 1,	-- RowStatus - tinyint
			 NEWID(),	-- Guid - uniqueidentifier
			 @Recipients,	-- Recipients - nvarchar(max)
			 @Subject,	-- Subject - nvarchar(255)
			 @Body,	-- Body - nvarchar(max)
			 @BodyFormat,	-- BodyFormat - nvarchar(20)
			 @Importance,	-- Importance - nvarchar(6)
			 NULL		-- DateTimeSent - datetime2(7)
		 )
END
GO