SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantConversationUpsert]')
GO

/*
    9. CRUD / Upsert / Read Layer
    ----------------------------
    Adds the first usable persistence and read surface for SAi.
*/
/* =========================================================================================
   9.1 Conversation create / upsert
========================================================================================= */
CREATE PROCEDURE [SAi].[AssistantConversationUpsert] (
	@UserId INT
	,@Title NVARCHAR(250)
	,@ModeCode NVARCHAR(20)
	,@LanguageCode NVARCHAR(20) = NULL
	,@IsPinned BIT = 0
	,@IsArchived BIT = 0
	,@StartedFromWorkflowTemplateGuid UNIQUEIDENTIFIER = NULL
	,@Guid UNIQUEIDENTIFIER OUTPUT
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();
	DECLARE @StartedFromWorkflowTemplateId INT = NULL;
	DECLARE @EntityTypeId INT;
	DECLARE @ExistingId INT;

	IF @Guid IS NULL
	BEGIN
		SET @Guid = NEWID();
	END;

	IF @StartedFromWorkflowTemplateGuid IS NOT NULL
		AND @StartedFromWorkflowTemplateGuid <> '00000000-0000-0000-0000-000000000000'
	BEGIN
		SELECT @StartedFromWorkflowTemplateId = wt.ID
		FROM SAi.AssistantWorkflowTemplates AS wt
		WHERE wt.Guid = @StartedFromWorkflowTemplateGuid
			AND wt.RowStatus NOT IN (
				0
				,254
				);
	END;

	SELECT @EntityTypeId = et.ID
	FROM SCore.EntityTypes AS et
	WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000001'
		AND et.RowStatus NOT IN (
			0
			,254
			);

	IF @EntityTypeId IS NULL
	BEGIN
			;

		THROW 60102
			,N'Assistant Conversations EntityType could not be resolved.'
			,1;
	END;

	SELECT @ExistingId = c.ID
	FROM SAi.AssistantConversations AS c
	WHERE c.Guid = @Guid;

	IF @ExistingId IS NULL
	BEGIN
		EXEC SAi.Assistant_CreateDataObject @Guid = @Guid
			,@EntityTypeId = @EntityTypeId
			,@RowStatus = 1;

		INSERT INTO SAi.AssistantConversations (
			RowStatus
			,Guid
			,UserId
			,Title
			,ModeCode
			,LanguageCode
			,LastActivityUtc
			,IsPinned
			,IsArchived
			,StartedFromWorkflowTemplateId
			,LastMessageId
			)
		VALUES (
			1
			,@Guid
			,@UserId
			,@Title
			,@ModeCode
			,@LanguageCode
			,@NowUtc
			,@IsPinned
			,@IsArchived
			,@StartedFromWorkflowTemplateId
			,NULL
			);
	END
	ELSE
	BEGIN
		UPDATE SAi.AssistantConversations
		SET RowStatus = 1
			,UserId = @UserId
			,Title = @Title
			,ModeCode = @ModeCode
			,LanguageCode = @LanguageCode
			,IsPinned = @IsPinned
			,IsArchived = @IsArchived
			,StartedFromWorkflowTemplateId = @StartedFromWorkflowTemplateId
			,LastActivityUtc = @NowUtc
		WHERE Guid = @Guid;
	END;
END;
GO