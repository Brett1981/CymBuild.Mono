SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantFeedbackCreate]')
GO

/* =========================================================================================
   9.9 Feedback create
========================================================================================= */
CREATE PROCEDURE [SAi].[AssistantFeedbackCreate] (
	@UserId INT
	,@ConversationGuid UNIQUEIDENTIFIER
	,@MessageGuid UNIQUEIDENTIFIER
	,@FeedbackCode NVARCHAR(20)
	,@Comment NVARCHAR(MAX) = NULL
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

		THROW 60140
			,N'Conversation or message not found for feedback creation.'
			,1;
	END;

	EXEC SCore.UpsertDataObject @Guid = @Guid
		,@SchemeName = N'SAi'
		,@ObjectName = N'AssistantFeedback'
		,@IsInsert = @IsInsert OUTPUT;

	IF (@IsInsert = 0)
	BEGIN
			;

		THROW 60141
			,N'AssistantFeedbackCreate only supports new feedback creation.'
			,1;
	END;

	INSERT SAi.AssistantFeedback (
		Guid
		,RowStatus
		,UserId
		,ConversationId
		,MessageId
		,FeedbackCode
		,Comment
		,CreatedUtc
		)
	VALUES (
		@Guid
		,1
		,@UserId
		,@ConversationId
		,@MessageId
		,@FeedbackCode
		,@Comment
		,@NowUtc
		);
END;
GO