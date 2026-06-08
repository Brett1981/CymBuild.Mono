SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantContentGapUpsert]')
GO

/* =========================================================================================
   9.11 Content gap upsert
========================================================================================= */
CREATE PROCEDURE [SAi].[AssistantContentGapUpsert] (
	@Title NVARCHAR(500)
	,@Description NVARCHAR(MAX) = NULL
	,@TopicCluster NVARCHAR(250) = NULL
	,@OccurrenceCountIncrement INT = 1
	,@StatusCode NVARCHAR(30)
	,@SuggestedKnowledgeItemGuid UNIQUEIDENTIFIER = NULL
	,@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @SuggestedKnowledgeItemId INT = NULL;
	DECLARE @IsInsert BIT = 0;
	DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();

	IF (
			@SuggestedKnowledgeItemGuid IS NOT NULL
			AND @SuggestedKnowledgeItemGuid <> '00000000-0000-0000-0000-000000000000'
			)
	BEGIN
		SELECT @SuggestedKnowledgeItemId = ki.ID
		FROM SAi.AssistantKnowledgeItems ki
		WHERE ki.Guid = @SuggestedKnowledgeItemGuid
			AND ki.RowStatus NOT IN (
				0
				,254
				);
	END;

	EXEC SCore.UpsertDataObject @Guid = @Guid
		,@SchemeName = N'SAi'
		,@ObjectName = N'AssistantContentGaps'
		,@IsInsert = @IsInsert OUTPUT;

	IF (@IsInsert = 1)
	BEGIN
		INSERT SAi.AssistantContentGaps (
			Guid
			,RowStatus
			,Title
			,Description
			,TopicCluster
			,OccurrenceCount
			,LastSeenUtc
			,StatusCode
			,SuggestedKnowledgeItemId
			)
		VALUES (
			@Guid
			,1
			,@Title
			,@Description
			,@TopicCluster
			,CASE 
				WHEN @OccurrenceCountIncrement < 1
					THEN 1
				ELSE @OccurrenceCountIncrement
				END
			,@NowUtc
			,@StatusCode
			,@SuggestedKnowledgeItemId
			);
	END
	ELSE
	BEGIN
		UPDATE SAi.AssistantContentGaps
		SET RowStatus = 1
			,Title = @Title
			,Description = @Description
			,TopicCluster = @TopicCluster
			,OccurrenceCount = ISNULL(OccurrenceCount, 0) + CASE 
				WHEN @OccurrenceCountIncrement < 1
					THEN 1
				ELSE @OccurrenceCountIncrement
				END
			,LastSeenUtc = @NowUtc
			,StatusCode = @StatusCode
			,SuggestedKnowledgeItemId = @SuggestedKnowledgeItemId
		WHERE Guid = @Guid;
	END;
END;
GO