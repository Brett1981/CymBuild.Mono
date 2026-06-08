SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantKnowledgeItemUpsert]')
GO

/* =========================================================================================
   9.4 Knowledge item upsert
========================================================================================= */
CREATE PROCEDURE [SAi].[AssistantKnowledgeItemUpsert] (
	@Title NVARCHAR(500)
	,@Slug NVARCHAR(500)
	,@KnowledgeCategoryGuid UNIQUEIDENTIFIER = NULL
	,@ContentTypeCode NVARCHAR(30)
	,@SourceTypeCode NVARCHAR(30)
	,@StorageUrl NVARCHAR(1000)
	,@PreviewUrl NVARCHAR(1000) = NULL
	,@Summary NVARCHAR(MAX) = NULL
	,@IsAuthoritative BIT = 0
	,@IsPublished BIT = 0
	,@CreatedByUserId INT
	,@UpdatedByUserId INT = NULL
	,@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @KnowledgeCategoryId INT = NULL;
	DECLARE @IsInsert BIT = 0;
	DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();

	IF (
			@KnowledgeCategoryGuid IS NOT NULL
			AND @KnowledgeCategoryGuid <> '00000000-0000-0000-0000-000000000000'
			)
	BEGIN
		SELECT @KnowledgeCategoryId = c.ID
		FROM SAi.AssistantKnowledgeCategories c
		WHERE c.Guid = @KnowledgeCategoryGuid
			AND c.RowStatus NOT IN (
				0
				,254
				);
	END;

	EXEC SCore.UpsertDataObject @Guid = @Guid
		,@SchemeName = N'SAi'
		,@ObjectName = N'AssistantKnowledgeItems'
		,@IsInsert = @IsInsert OUTPUT;

	IF (@IsInsert = 1)
	BEGIN
		INSERT SAi.AssistantKnowledgeItems (
			Guid
			,RowStatus
			,Title
			,Slug
			,KnowledgeCategoryId
			,ContentTypeCode
			,SourceTypeCode
			,StorageUrl
			,PreviewUrl
			,Summary
			,IsAuthoritative
			,IsPublished
			,PublishedUtc
			,CreatedByUserId
			,UpdatedByUserId
			,CreatedUtc
			,UpdatedUtc
			)
		VALUES (
			@Guid
			,1
			,@Title
			,@Slug
			,@KnowledgeCategoryId
			,@ContentTypeCode
			,@SourceTypeCode
			,@StorageUrl
			,@PreviewUrl
			,@Summary
			,@IsAuthoritative
			,@IsPublished
			,CASE 
				WHEN @IsPublished = 1
					THEN @NowUtc
				ELSE NULL
				END
			,@CreatedByUserId
			,@UpdatedByUserId
			,@NowUtc
			,CASE 
				WHEN @UpdatedByUserId IS NULL
					THEN NULL
				ELSE @NowUtc
				END
			);
	END
	ELSE
	BEGIN
		UPDATE SAi.AssistantKnowledgeItems
		SET RowStatus = 1
			,Title = @Title
			,Slug = @Slug
			,KnowledgeCategoryId = @KnowledgeCategoryId
			,ContentTypeCode = @ContentTypeCode
			,SourceTypeCode = @SourceTypeCode
			,StorageUrl = @StorageUrl
			,PreviewUrl = @PreviewUrl
			,Summary = @Summary
			,IsAuthoritative = @IsAuthoritative
			,IsPublished = @IsPublished
			,PublishedUtc = CASE 
				WHEN @IsPublished = 1
					AND PublishedUtc IS NULL
					THEN @NowUtc
				ELSE PublishedUtc
				END
			,UpdatedByUserId = @UpdatedByUserId
			,UpdatedUtc = @NowUtc
		WHERE Guid = @Guid;
	END;
END;
GO