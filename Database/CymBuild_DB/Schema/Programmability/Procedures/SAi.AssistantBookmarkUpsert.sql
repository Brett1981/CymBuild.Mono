SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantBookmarkUpsert]')
GO

/* =========================================================================================
   9.3 Bookmark upsert
========================================================================================= */
CREATE PROCEDURE [SAi].[AssistantBookmarkUpsert] (
	@UserId INT
	,@ConversationGuid UNIQUEIDENTIFIER
	,@MessageGuid UNIQUEIDENTIFIER
	,@Title NVARCHAR(250)
	,@Notes NVARCHAR(MAX) = NULL
	,@TagsJson NVARCHAR(MAX) = NULL
	,@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ConversationId INT;
	DECLARE @MessageId INT;
	DECLARE @IsInsert BIT = 0;
	DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();

	SELECT @ConversationId = c.ID
	FROM SAi.AssistantConversations c
	WHERE c.Guid = @ConversationGuid
		AND c.RowStatus NOT IN (
			0
			,254
			);

	SELECT @MessageId = m.ID
	FROM SAi.AssistantMessages m
	WHERE m.Guid = @MessageGuid
		AND m.RowStatus NOT IN (
			0
			,254
			);

	IF @ConversationId IS NULL
		OR @MessageId IS NULL
	BEGIN
			;

		THROW 60110
			,N'Conversation or message not found for bookmark upsert.'
			,1;
	END;

	EXEC SCore.UpsertDataObject @Guid = @Guid
		,@SchemeName = N'SAi'
		,@ObjectName = N'AssistantBookmarks'
		,@IsInsert = @IsInsert OUTPUT;

	IF (@IsInsert = 1)
	BEGIN
		INSERT SAi.AssistantBookmarks (
			Guid
			,RowStatus
			,UserId
			,ConversationId
			,MessageId
			,Title
			,Notes
			,TagsJson
			,CreatedUtc
			)
		VALUES (
			@Guid
			,1
			,@UserId
			,@ConversationId
			,@MessageId
			,@Title
			,@Notes
			,@TagsJson
			,@NowUtc
			);
	END
	ELSE
	BEGIN
		UPDATE SAi.AssistantBookmarks
		SET RowStatus = 1
			,UserId = @UserId
			,ConversationId = @ConversationId
			,MessageId = @MessageId
			,Title = @Title
			,Notes = @Notes
			,TagsJson = @TagsJson
		WHERE Guid = @Guid;
	END;
END;
GO