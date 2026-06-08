SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantMessageCreate]')
GO

/* =========================================================================================
   9.2 Message create
========================================================================================= */
CREATE PROCEDURE [SAi].[AssistantMessageCreate] (
	@ConversationGuid UNIQUEIDENTIFIER
	,@UserId INT
	,@MessageRoleCode NVARCHAR(20)
	,@AnswerTypeCode NVARCHAR(30) = NULL
	,@ContentMarkdown NVARCHAR(MAX)
	,@ContentPlainText NVARCHAR(MAX) = NULL
	,@SourcePayloadJson NVARCHAR(MAX) = NULL
	,@FollowUpPayloadJson NVARCHAR(MAX) = NULL
	,@ConfidenceScore DECIMAL(5, 4) = NULL
	,@PromptTokens INT = NULL
	,@CompletionTokens INT = NULL
	,@ModelCode NVARCHAR(100) = NULL
	,@ParentMessageGuid UNIQUEIDENTIFIER = NULL
	,@Guid UNIQUEIDENTIFIER OUTPUT
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ConversationId INT;
	DECLARE @ParentMessageId INT = NULL;
	DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();
	DECLARE @NewMessageId INT;
	DECLARE @EntityTypeId INT;

	IF @Guid IS NULL
	BEGIN
		SET @Guid = NEWID();
	END;

	IF EXISTS (
			SELECT 1
			FROM SAi.AssistantMessages AS m
			WHERE m.Guid = @Guid
			)
	BEGIN
			;

		THROW 60101
			,N'AssistantMessageCreate only supports new message creation for deterministic auditability.'
			,1;
	END;

	SELECT @ConversationId = c.ID
	FROM SAi.AssistantConversations AS c
	WHERE c.Guid = @ConversationGuid
		AND c.RowStatus NOT IN (
			0
			,254
			);

	IF @ConversationId IS NULL
	BEGIN
			;

		THROW 60100
			,N'Conversation not found for AssistantMessageCreate.'
			,1;
	END;

	IF @ParentMessageGuid IS NOT NULL
		AND @ParentMessageGuid <> '00000000-0000-0000-0000-000000000000'
	BEGIN
		SELECT @ParentMessageId = m.ID
		FROM SAi.AssistantMessages AS m
		WHERE m.Guid = @ParentMessageGuid
			AND m.RowStatus NOT IN (
				0
				,254
				);
	END;

	SELECT @EntityTypeId = et.ID
	FROM SCore.EntityTypes AS et
	WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000002'
		AND et.RowStatus NOT IN (
			0
			,254
			);

	IF @EntityTypeId IS NULL
	BEGIN
			;

		THROW 60103
			,N'Assistant Messages EntityType could not be resolved.'
			,1;
	END;

	EXEC SAi.Assistant_CreateDataObject @Guid = @Guid
		,@EntityTypeId = @EntityTypeId
		,@RowStatus = 1;

	INSERT INTO SAi.AssistantMessages (
		RowStatus
		,Guid
		,ConversationId
		,UserId
		,MessageRoleCode
		,AnswerTypeCode
		,ContentMarkdown
		,ContentPlainText
		,SourcePayloadJson
		,FollowUpPayloadJson
		,ConfidenceScore
		,CreatedUtc
		,PromptTokens
		,CompletionTokens
		,ModelCode
		,ParentMessageId
		)
	VALUES (
		1
		,@Guid
		,@ConversationId
		,@UserId
		,@MessageRoleCode
		,@AnswerTypeCode
		,@ContentMarkdown
		,@ContentPlainText
		,@SourcePayloadJson
		,@FollowUpPayloadJson
		,@ConfidenceScore
		,@NowUtc
		,@PromptTokens
		,@CompletionTokens
		,@ModelCode
		,@ParentMessageId
		);

	SET @NewMessageId = CONVERT(INT, SCOPE_IDENTITY());

	UPDATE SAi.AssistantConversations
	SET LastActivityUtc = @NowUtc
		,LastMessageId = @NewMessageId
	WHERE ID = @ConversationId;
END;
GO