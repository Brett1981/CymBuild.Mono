SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantUploadCreate]')
GO

/* =========================================================================================
   9.8 Upload create
========================================================================================= */
CREATE PROCEDURE [SAi].[AssistantUploadCreate] (
	@UserId INT
	,@ConversationGuid UNIQUEIDENTIFIER = NULL
	,@KnowledgeItemGuid UNIQUEIDENTIFIER = NULL
	,@StorageUrl NVARCHAR(1000)
	,@FileName NVARCHAR(500)
	,@ContentType NVARCHAR(200)
	,@FileSizeBytes BIGINT
	,@UploadPurposeCode NVARCHAR(30)
	,@ProcessingStatusCode NVARCHAR(30)
	,@VisionSummary NVARCHAR(MAX) = NULL
	,@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ConversationId INT = NULL;
	DECLARE @KnowledgeItemId INT = NULL;
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

	IF (
			@KnowledgeItemGuid IS NOT NULL
			AND @KnowledgeItemGuid <> '00000000-0000-0000-0000-000000000000'
			)
	BEGIN
		SELECT @KnowledgeItemId = ki.ID
		FROM SAi.AssistantKnowledgeItems ki
		WHERE ki.Guid = @KnowledgeItemGuid
			AND ki.RowStatus NOT IN (
				0
				,254
				);
	END;

	EXEC SCore.UpsertDataObject @Guid = @Guid
		,@SchemeName = N'SAi'
		,@ObjectName = N'AssistantUploads'
		,@IsInsert = @IsInsert OUTPUT;

	IF (@IsInsert = 1)
	BEGIN
		INSERT SAi.AssistantUploads (
			Guid
			,RowStatus
			,UserId
			,ConversationId
			,KnowledgeItemId
			,StorageUrl
			,FileName
			,ContentType
			,FileSizeBytes
			,UploadPurposeCode
			,ProcessingStatusCode
			,VisionSummary
			,CreatedUtc
			)
		VALUES (
			@Guid
			,1
			,@UserId
			,@ConversationId
			,@KnowledgeItemId
			,@StorageUrl
			,@FileName
			,@ContentType
			,@FileSizeBytes
			,@UploadPurposeCode
			,@ProcessingStatusCode
			,@VisionSummary
			,@NowUtc
			);
	END
	ELSE
	BEGIN
		UPDATE SAi.AssistantUploads
		SET RowStatus = 1
			,UserId = @UserId
			,ConversationId = @ConversationId
			,KnowledgeItemId = @KnowledgeItemId
			,StorageUrl = @StorageUrl
			,FileName = @FileName
			,ContentType = @ContentType
			,FileSizeBytes = @FileSizeBytes
			,UploadPurposeCode = @UploadPurposeCode
			,ProcessingStatusCode = @ProcessingStatusCode
			,VisionSummary = @VisionSummary
		WHERE Guid = @Guid;
	END;
END;
GO