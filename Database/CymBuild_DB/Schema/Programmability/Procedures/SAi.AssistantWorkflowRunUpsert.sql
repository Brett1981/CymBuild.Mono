SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantWorkflowRunUpsert]')
GO

/* =========================================================================================
   9.7 Workflow run upsert
========================================================================================= */
CREATE PROCEDURE [SAi].[AssistantWorkflowRunUpsert] (
	@UserId INT
	,@WorkflowTemplateGuid UNIQUEIDENTIFIER
	,@ConversationGuid UNIQUEIDENTIFIER = NULL
	,@StatusCode NVARCHAR(30)
	,@InputJson NVARCHAR(MAX) = NULL
	,@OutputJson NVARCHAR(MAX) = NULL
	,@CompletedUtc DATETIME2(7) = NULL
	,@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @WorkflowTemplateId INT;
	DECLARE @ConversationId INT = NULL;
	DECLARE @IsInsert BIT = 0;
	DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();

	SELECT @WorkflowTemplateId = wt.ID
	FROM SAi.AssistantWorkflowTemplates wt
	WHERE wt.Guid = @WorkflowTemplateGuid
		AND wt.RowStatus NOT IN (
			0
			,254
			);

	IF @WorkflowTemplateId IS NULL
	BEGIN
			;

		THROW 60130
			,N'Workflow template not found for workflow run upsert.'
			,1;
	END;

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
		,@ObjectName = N'AssistantWorkflowRuns'
		,@IsInsert = @IsInsert OUTPUT;

	IF (@IsInsert = 1)
	BEGIN
		INSERT SAi.AssistantWorkflowRuns (
			Guid
			,RowStatus
			,UserId
			,WorkflowTemplateId
			,ConversationId
			,StatusCode
			,InputJson
			,OutputJson
			,StartedUtc
			,CompletedUtc
			)
		VALUES (
			@Guid
			,1
			,@UserId
			,@WorkflowTemplateId
			,@ConversationId
			,@StatusCode
			,@InputJson
			,@OutputJson
			,@NowUtc
			,@CompletedUtc
			);
	END
	ELSE
	BEGIN
		UPDATE SAi.AssistantWorkflowRuns
		SET RowStatus = 1
			,UserId = @UserId
			,WorkflowTemplateId = @WorkflowTemplateId
			,ConversationId = @ConversationId
			,StatusCode = @StatusCode
			,InputJson = @InputJson
			,OutputJson = @OutputJson
			,CompletedUtc = @CompletedUtc
		WHERE Guid = @Guid;
	END;
END;
GO