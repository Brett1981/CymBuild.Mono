SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantKnowledgeItemVersionCreate]')
GO

/* =========================================================================================
   9.5 Knowledge version create
========================================================================================= */
CREATE PROCEDURE [SAi].[AssistantKnowledgeItemVersionCreate] (
	@KnowledgeItemGuid UNIQUEIDENTIFIER
	,@StorageUrl NVARCHAR(1000)
	,@ExtractedText NVARCHAR(MAX) = NULL
	,@ExtractionStatusCode NVARCHAR(30)
	,@MetadataJson NVARCHAR(MAX) = NULL
	,@FileHash NVARCHAR(200) = NULL
	,@CreatedByUserId INT
	,@Guid UNIQUEIDENTIFIER OUTPUT
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @KnowledgeItemId INT;
	DECLARE @VersionNumber INT;
	DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();
	DECLARE @EntityTypeId INT;

	IF @Guid IS NULL
	BEGIN
		SET @Guid = NEWID();
	END;

	IF EXISTS (
			SELECT 1
			FROM SAi.AssistantKnowledgeItemVersions AS v
			WHERE v.Guid = @Guid
			)
	BEGIN
			;

		THROW 60121
			,N'AssistantKnowledgeItemVersionCreate only supports creation of new versions.'
			,1;
	END;

	SELECT @KnowledgeItemId = ki.ID
	FROM SAi.AssistantKnowledgeItems AS ki
	WHERE ki.Guid = @KnowledgeItemGuid
		AND ki.RowStatus NOT IN (
			0
			,254
			);

	IF @KnowledgeItemId IS NULL
	BEGIN
			;

		THROW 60120
			,N'Knowledge item not found for version creation.'
			,1;
	END;

	SELECT @EntityTypeId = et.ID
	FROM SCore.EntityTypes AS et
	WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000007'
		AND et.RowStatus NOT IN (
			0
			,254
			);

	IF @EntityTypeId IS NULL
	BEGIN
			;

		THROW 60122
			,N'Assistant Knowledge Item Versions EntityType could not be resolved.'
			,1;
	END;

	SELECT @VersionNumber = ISNULL(MAX(v.VersionNumber), 0) + 1
	FROM SAi.AssistantKnowledgeItemVersions AS v WITH (
			UPDLOCK
			,HOLDLOCK
			)
	WHERE v.KnowledgeItemId = @KnowledgeItemId;

	EXEC SAi.Assistant_CreateDataObject @Guid = @Guid
		,@EntityTypeId = @EntityTypeId
		,@RowStatus = 1;

	UPDATE SAi.AssistantKnowledgeItemVersions
	SET IsCurrent = 0
	WHERE KnowledgeItemId = @KnowledgeItemId
		AND IsCurrent = 1;

	INSERT INTO SAi.AssistantKnowledgeItemVersions (
		RowStatus
		,Guid
		,KnowledgeItemId
		,VersionNumber
		,StorageUrl
		,ExtractedText
		,ExtractionStatusCode
		,MetadataJson
		,FileHash
		,IsCurrent
		,CreatedByUserId
		,CreatedUtc
		)
	VALUES (
		1
		,@Guid
		,@KnowledgeItemId
		,@VersionNumber
		,@StorageUrl
		,@ExtractedText
		,@ExtractionStatusCode
		,@MetadataJson
		,@FileHash
		,1
		,@CreatedByUserId
		,@NowUtc
		);
END;
GO