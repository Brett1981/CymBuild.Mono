SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantAnalyticsEventCreate]')
GO

/* =========================================================================================
   9.10 Analytics event create
========================================================================================= */
CREATE PROCEDURE [SAi].[AssistantAnalyticsEventCreate] (
	@UserId INT = NULL
	,@ConversationGuid UNIQUEIDENTIFIER = NULL
	,@EventTypeCode NVARCHAR(50)
	,@TopicText NVARCHAR(1000) = NULL
	,@PayloadJson NVARCHAR(MAX) = NULL
	,@SuccessFlag BIT = NULL
	,@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ConversationId INT = NULL;
	DECLARE @IsInsert BIT = 0;
	DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();

	IF (
			@ConversationGuid IS NOT NULL
			AND @ConversationGuid <> '00000000-0000-0000-0000-000000000000'
			)
	BEGIN
		SELECT @ConversationId = c.ID
		FROM SAi.AssistantConversations c
		WHERE c.Guid = @ConversationGuid
			AND c.RowStatus NOT IN (
				0
				,254
				);
	END;

	EXEC SCore.UpsertDataObject @Guid = @Guid
		,@SchemeName = N'SAi'
		,@ObjectName = N'AssistantAnalyticsEvents'
		,@IsInsert = @IsInsert OUTPUT;

	IF (@IsInsert = 0)
	BEGIN
			;

		THROW 60150
			,N'AssistantAnalyticsEventCreate only supports new event creation.'
			,1;
	END;

	INSERT SAi.AssistantAnalyticsEvents (
		Guid
		,RowStatus
		,UserId
		,ConversationId
		,EventTypeCode
		,EventUtc
		,TopicText
		,PayloadJson
		,SuccessFlag
		)
	VALUES (
		@Guid
		,1
		,@UserId
		,@ConversationId
		,@EventTypeCode
		,@NowUtc
		,@TopicText
		,@PayloadJson
		,@SuccessFlag
		);
END;
GO