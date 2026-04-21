SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
    CymBuild AI Assistant - SQL Foundation
    -------------------------------------
    Production-ready foundation script for the SAi schema.

    DESIGN PRINCIPLES
    -----------------
    1. SQL Server only.
    2. Idempotent where practical for deployment usage.
    3. Every major entity gets a matching SCore.DataObjects row at insert time.
    4. EntityTypeId is set at insert time - no insert-then-update pattern.
    5. No workflow statuses are added here; workflow can be layered later.
    6. All user-owned records persist UserId as requested.
    7. RowStatus filtering patterns remain CymBuild-compatible.

    INCLUDED
    --------
    - SAi schema creation
    - EntityType seeding for assistant entities
    - Core assistant tables
    - Foreign keys and indexes
    - Helper procedures for safe EntityType seeding

    NOT INCLUDED YET
    ----------------
    - Metadata UI seeding for admin grids/forms
    - Workflow definitions/statuses/transitions
    - Read TVFs/views
    - CRUD/upsert procedures for each SAi table
    - Retrieval/search/vector infrastructure

    IMPORTANT
    ---------
    This script uses existing platform procedures where available:
      - SCore.LanguageLabelUpsert
      - SCore.EntityTypeUpsert

    The script resolves an existing Icon Guid dynamically from SUserInterface.Icons.
    If your environment has special icon requirements, replace the fallback selection.
*/
/* =========================================================================================
       1. Ensure schema exists
    ========================================================================================= */
IF NOT EXISTS (
		SELECT 1
		FROM sys.schemas s
		WHERE s.name = N'SAi'
		)
BEGIN
	EXEC (N'CREATE SCHEMA SAi');
END;
GO

/* =========================================================================================
       2. Helper procedure for assistant EntityType creation
          - Creates LanguageLabel if needed
          - Creates EntityType as a proper DataObject-backed entity via SCore.EntityTypeUpsert
    ========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.Assistant_EnsureEntityType (
	@EntityTypeName NVARCHAR(250)
	,@DetailPageUrl NVARCHAR(250)
	,@EntityTypeGuid UNIQUEIDENTIFIER
	,@LanguageLabelGuid UNIQUEIDENTIFIER
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ExistingId INT;
	DECLARE @IconGuid UNIQUEIDENTIFIER;
	DECLARE @ResolvedLanguageLabelGuid UNIQUEIDENTIFIER = @LanguageLabelGuid;
	DECLARE @ResolvedEntityTypeGuid UNIQUEIDENTIFIER = @EntityTypeGuid;

	SELECT @ExistingId = et.ID
	FROM SCore.EntityTypes AS et
	WHERE et.Guid = @EntityTypeGuid
		AND et.RowStatus NOT IN (
			0
			,254
			);

	IF @ExistingId IS NOT NULL
	BEGIN
		RETURN;
	END;

	SELECT TOP (1) @IconGuid = i.Guid
	FROM SUserInterface.Icons AS i
	WHERE i.RowStatus NOT IN (
			0
			,254
			)
	ORDER BY i.ID;

	IF @IconGuid IS NULL
	BEGIN
			;

		THROW 60000
			,N'Unable to resolve a fallback Icon Guid from SUserInterface.Icons.'
			,1;
	END;

	EXEC SCore.LanguageLabelUpsert @Name = @EntityTypeName
		,@Guid = @ResolvedLanguageLabelGuid OUTPUT;

	EXEC SCore.EntityTypeUpsert @Name = @EntityTypeName
		,@RowStatus = 1
		,@IsReadOnlyOffline = 0
		,@IsRequiredSystemData = 0
		,@HasDocuments = 0
		,@LanguageLabelGuid = @ResolvedLanguageLabelGuid
		,@DoNotTrackChanges = 0
		,@IconGuid = @IconGuid
		,@IsRootEntity = 0
		,@DetailPageUrl = @DetailPageUrl
		,@IsMetaData = 0
		,@Guid = @ResolvedEntityTypeGuid OUTPUT;
END;

/* =========================================================================================
       3. Seed EntityTypes for SAi major entities
          - Fixed GUIDs so later deployments and metadata can reference them deterministically.
    ========================================================================================= */
EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Conversations'
	,@DetailPageUrl = N'/assistant/app/chat'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000001'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100001';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Messages'
	,@DetailPageUrl = N'/assistant/app/chat'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000002'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100002';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Bookmarks'
	,@DetailPageUrl = N'/assistant/app/bookmarks'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000003'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100003';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Playbooks'
	,@DetailPageUrl = N'/assistant/app/playbooks'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000004'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100004';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Playbook Steps'
	,@DetailPageUrl = N'/assistant/app/playbooks'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000005'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100005';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Knowledge Items'
	,@DetailPageUrl = N'/assistant/app/knowledge'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000006'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100006';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Knowledge Item Versions'
	,@DetailPageUrl = N'/assistant/admin/content'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000007'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100007';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Knowledge Categories'
	,@DetailPageUrl = N'/assistant/admin/content'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000008'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100008';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Knowledge Tags'
	,@DetailPageUrl = N'/assistant/admin/content'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000009'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100009';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Knowledge Item Tags'
	,@DetailPageUrl = N'/assistant/admin/content'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000010'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100010';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Uploads'
	,@DetailPageUrl = N'/assistant/app/uploads'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000011'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100011';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Workflow Templates'
	,@DetailPageUrl = N'/assistant/admin/workflows'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000012'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100012';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Workflow Runs'
	,@DetailPageUrl = N'/assistant/app/playbooks'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000013'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100013';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Workflow Run Steps'
	,@DetailPageUrl = N'/assistant/app/playbooks'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000014'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100014';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Feedback'
	,@DetailPageUrl = N'/assistant/admin/review'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000015'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100015';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Analytics Events'
	,@DetailPageUrl = N'/assistant/admin/analytics'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000016'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100016';

EXEC SAi.Assistant_EnsureEntityType @EntityTypeName = N'Assistant Content Gaps'
	,@DetailPageUrl = N'/assistant/admin/analytics'
	,@EntityTypeGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000017'
	,@LanguageLabelGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2100017';

DECLARE @Et_AssistantConversations INT;
DECLARE @Et_AssistantMessages INT;
DECLARE @Et_AssistantBookmarks INT;
DECLARE @Et_AssistantPlaybooks INT;
DECLARE @Et_AssistantPlaybookSteps INT;
DECLARE @Et_AssistantKnowledgeItems INT;
DECLARE @Et_AssistantKnowledgeVersions INT;
DECLARE @Et_AssistantKnowledgeCategories INT;
DECLARE @Et_AssistantKnowledgeTags INT;
DECLARE @Et_AssistantKnowledgeItemTags INT;
DECLARE @Et_AssistantUploads INT;
DECLARE @Et_AssistantWorkflowTemplates INT;
DECLARE @Et_AssistantWorkflowRuns INT;
DECLARE @Et_AssistantWorkflowRunSteps INT;
DECLARE @Et_AssistantFeedback INT;
DECLARE @Et_AssistantAnalyticsEvents INT;
DECLARE @Et_AssistantContentGaps INT;

SELECT @Et_AssistantConversations = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000001';

SELECT @Et_AssistantMessages = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000002';

SELECT @Et_AssistantBookmarks = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000003';

SELECT @Et_AssistantPlaybooks = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000004';

SELECT @Et_AssistantPlaybookSteps = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000005';

SELECT @Et_AssistantKnowledgeItems = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000006';

SELECT @Et_AssistantKnowledgeVersions = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000007';

SELECT @Et_AssistantKnowledgeCategories = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000008';

SELECT @Et_AssistantKnowledgeTags = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000009';

SELECT @Et_AssistantKnowledgeItemTags = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000010';

SELECT @Et_AssistantUploads = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000011';

SELECT @Et_AssistantWorkflowTemplates = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000012';

SELECT @Et_AssistantWorkflowRuns = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000013';

SELECT @Et_AssistantWorkflowRunSteps = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000014';

SELECT @Et_AssistantFeedback = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000015';

SELECT @Et_AssistantAnalyticsEvents = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000016';

SELECT @Et_AssistantContentGaps = et.ID
FROM SCore.EntityTypes et
WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000017';

IF @Et_AssistantConversations IS NULL
	OR @Et_AssistantMessages IS NULL
	OR @Et_AssistantBookmarks IS NULL
	OR @Et_AssistantPlaybooks IS NULL
	OR @Et_AssistantPlaybookSteps IS NULL
	OR @Et_AssistantKnowledgeItems IS NULL
	OR @Et_AssistantKnowledgeVersions IS NULL
	OR @Et_AssistantKnowledgeCategories IS NULL
	OR @Et_AssistantKnowledgeTags IS NULL
	OR @Et_AssistantKnowledgeItemTags IS NULL
	OR @Et_AssistantUploads IS NULL
	OR @Et_AssistantWorkflowTemplates IS NULL
	OR @Et_AssistantWorkflowRuns IS NULL
	OR @Et_AssistantWorkflowRunSteps IS NULL
	OR @Et_AssistantFeedback IS NULL
	OR @Et_AssistantAnalyticsEvents IS NULL
	OR @Et_AssistantContentGaps IS NULL
BEGIN
		;

	THROW 60001
		,N'One or more SAi EntityTypes could not be resolved after seeding.'
		,1;
END;

/* =========================================================================================
       4. Core tables
    ========================================================================================= */
IF OBJECT_ID(N'SAi.AssistantConversations', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantConversations (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,UserId INT NOT NULL
		,Title NVARCHAR(250) NOT NULL
		,ModeCode NVARCHAR(20) NOT NULL
		,LanguageCode NVARCHAR(20) NULL
		,LastActivityUtc DATETIME2(7) NOT NULL
		,IsPinned BIT NOT NULL CONSTRAINT DF_AssistantConversations_IsPinned DEFAULT(0)
		,IsArchived BIT NOT NULL CONSTRAINT DF_AssistantConversations_IsArchived DEFAULT(0)
		,StartedFromWorkflowTemplateId INT NULL
		,LastMessageId INT NULL
		,CONSTRAINT PK_AssistantConversations PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantConversations_Guid UNIQUE NONCLUSTERED (Guid ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantMessages', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantMessages (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,ConversationId INT NOT NULL
		,UserId INT NOT NULL
		,MessageRoleCode NVARCHAR(20) NOT NULL
		,AnswerTypeCode NVARCHAR(30) NULL
		,ContentMarkdown NVARCHAR(MAX) NOT NULL
		,ContentPlainText NVARCHAR(MAX) NULL
		,SourcePayloadJson NVARCHAR(MAX) NULL
		,FollowUpPayloadJson NVARCHAR(MAX) NULL
		,ConfidenceScore DECIMAL(5, 4) NULL
		,CreatedUtc DATETIME2(7) NOT NULL
		,PromptTokens INT NULL
		,CompletionTokens INT NULL
		,ModelCode NVARCHAR(100) NULL
		,ParentMessageId INT NULL
		,CONSTRAINT PK_AssistantMessages PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantMessages_Guid UNIQUE NONCLUSTERED (Guid ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantBookmarks', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantBookmarks (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,UserId INT NOT NULL
		,ConversationId INT NOT NULL
		,MessageId INT NOT NULL
		,Title NVARCHAR(250) NOT NULL
		,Notes NVARCHAR(MAX) NULL
		,TagsJson NVARCHAR(MAX) NULL
		,CreatedUtc DATETIME2(7) NOT NULL
		,CONSTRAINT PK_AssistantBookmarks PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantBookmarks_Guid UNIQUE NONCLUSTERED (Guid ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantPlaybooks', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantPlaybooks (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,UserId INT NULL
		,Title NVARCHAR(250) NOT NULL
		,Summary NVARCHAR(1000) NULL
		,PlaybookTypeCode NVARCHAR(30) NOT NULL
		,VisibilityCode NVARCHAR(20) NOT NULL
		,SourceConversationId INT NULL
		,SourceWorkflowRunId INT NULL
		,CreatedByUserId INT NOT NULL
		,CreatedUtc DATETIME2(7) NOT NULL
		,UpdatedUtc DATETIME2(7) NULL
		,IsFeatured BIT NOT NULL CONSTRAINT DF_AssistantPlaybooks_IsFeatured DEFAULT(0)
		,CONSTRAINT PK_AssistantPlaybooks PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantPlaybooks_Guid UNIQUE NONCLUSTERED (Guid ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantPlaybookSteps', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantPlaybookSteps (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,PlaybookId INT NOT NULL
		,StepOrder INT NOT NULL
		,Title NVARCHAR(250) NOT NULL
		,InstructionMarkdown NVARCHAR(MAX) NOT NULL
		,IsOptional BIT NOT NULL CONSTRAINT DF_AssistantPlaybookSteps_IsOptional DEFAULT(0)
		,ExpectedOutcome NVARCHAR(1000) NULL
		,CONSTRAINT PK_AssistantPlaybookSteps PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantPlaybookSteps_Guid UNIQUE NONCLUSTERED (Guid ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantKnowledgeCategories', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantKnowledgeCategories (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,Name NVARCHAR(250) NOT NULL
		,Code NVARCHAR(50) NOT NULL
		,Description NVARCHAR(1000) NULL
		,DisplayOrder INT NOT NULL
		,IsVisible BIT NOT NULL CONSTRAINT DF_AssistantKnowledgeCategories_IsVisible DEFAULT(1)
		,CONSTRAINT PK_AssistantKnowledgeCategories PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantKnowledgeCategories_Guid UNIQUE NONCLUSTERED (Guid ASC)
		,CONSTRAINT UQ_AssistantKnowledgeCategories_Code UNIQUE NONCLUSTERED (Code ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantKnowledgeTags', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantKnowledgeTags (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,Name NVARCHAR(100) NOT NULL
		,Code NVARCHAR(50) NOT NULL
		,CONSTRAINT PK_AssistantKnowledgeTags PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantKnowledgeTags_Guid UNIQUE NONCLUSTERED (Guid ASC)
		,CONSTRAINT UQ_AssistantKnowledgeTags_Code UNIQUE NONCLUSTERED (Code ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantKnowledgeItems', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantKnowledgeItems (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,Title NVARCHAR(500) NOT NULL
		,Slug NVARCHAR(500) NOT NULL
		,KnowledgeCategoryId INT NULL
		,ContentTypeCode NVARCHAR(30) NOT NULL
		,SourceTypeCode NVARCHAR(30) NOT NULL
		,StorageUrl NVARCHAR(1000) NOT NULL
		,PreviewUrl NVARCHAR(1000) NULL
		,Summary NVARCHAR(MAX) NULL
		,IsAuthoritative BIT NOT NULL CONSTRAINT DF_AssistantKnowledgeItems_IsAuthoritative DEFAULT(0)
		,IsPublished BIT NOT NULL CONSTRAINT DF_AssistantKnowledgeItems_IsPublished DEFAULT(0)
		,PublishedUtc DATETIME2(7) NULL
		,CreatedByUserId INT NOT NULL
		,UpdatedByUserId INT NULL
		,CreatedUtc DATETIME2(7) NOT NULL
		,UpdatedUtc DATETIME2(7) NULL
		,CONSTRAINT PK_AssistantKnowledgeItems PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantKnowledgeItems_Guid UNIQUE NONCLUSTERED (Guid ASC)
		,CONSTRAINT UQ_AssistantKnowledgeItems_Slug UNIQUE NONCLUSTERED (Slug ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantKnowledgeItemVersions', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantKnowledgeItemVersions (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,KnowledgeItemId INT NOT NULL
		,VersionNumber INT NOT NULL
		,StorageUrl NVARCHAR(1000) NOT NULL
		,ExtractedText NVARCHAR(MAX) NULL
		,ExtractionStatusCode NVARCHAR(30) NOT NULL
		,MetadataJson NVARCHAR(MAX) NULL
		,FileHash NVARCHAR(200) NULL
		,IsCurrent BIT NOT NULL CONSTRAINT DF_AssistantKnowledgeItemVersions_IsCurrent DEFAULT(0)
		,CreatedByUserId INT NOT NULL
		,CreatedUtc DATETIME2(7) NOT NULL
		,CONSTRAINT PK_AssistantKnowledgeItemVersions PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantKnowledgeItemVersions_Guid UNIQUE NONCLUSTERED (Guid ASC)
		,CONSTRAINT UQ_AssistantKnowledgeItemVersions_ItemVersion UNIQUE NONCLUSTERED (
			KnowledgeItemId ASC
			,VersionNumber ASC
			)
		);
END;

IF OBJECT_ID(N'SAi.AssistantKnowledgeItemTags', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantKnowledgeItemTags (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,KnowledgeItemId INT NOT NULL
		,KnowledgeTagId INT NOT NULL
		,CONSTRAINT PK_AssistantKnowledgeItemTags PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantKnowledgeItemTags_Guid UNIQUE NONCLUSTERED (Guid ASC)
		,CONSTRAINT UQ_AssistantKnowledgeItemTags_Key UNIQUE NONCLUSTERED (
			KnowledgeItemId ASC
			,KnowledgeTagId ASC
			)
		);
END;

IF OBJECT_ID(N'SAi.AssistantUploads', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantUploads (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,UserId INT NOT NULL
		,ConversationId INT NULL
		,KnowledgeItemId INT NULL
		,StorageUrl NVARCHAR(1000) NOT NULL
		,FileName NVARCHAR(500) NOT NULL
		,ContentType NVARCHAR(200) NOT NULL
		,FileSizeBytes BIGINT NOT NULL
		,UploadPurposeCode NVARCHAR(30) NOT NULL
		,ProcessingStatusCode NVARCHAR(30) NOT NULL
		,VisionSummary NVARCHAR(MAX) NULL
		,CreatedUtc DATETIME2(7) NOT NULL
		,CONSTRAINT PK_AssistantUploads PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantUploads_Guid UNIQUE NONCLUSTERED (Guid ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantWorkflowTemplates', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantWorkflowTemplates (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,Code NVARCHAR(50) NOT NULL
		,Title NVARCHAR(250) NOT NULL
		,Summary NVARCHAR(1000) NULL
		,AudienceCode NVARCHAR(30) NULL
		,TemplatePrompt NVARCHAR(MAX) NOT NULL
		,ClarificationSchemaJson NVARCHAR(MAX) NULL
		,OutputFormatCode NVARCHAR(30) NOT NULL
		,IsPublished BIT NOT NULL CONSTRAINT DF_AssistantWorkflowTemplates_IsPublished DEFAULT(0)
		,IsFeatured BIT NOT NULL CONSTRAINT DF_AssistantWorkflowTemplates_IsFeatured DEFAULT(0)
		,CreatedByUserId INT NOT NULL
		,CreatedUtc DATETIME2(7) NOT NULL
		,UpdatedUtc DATETIME2(7) NULL
		,CONSTRAINT PK_AssistantWorkflowTemplates PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantWorkflowTemplates_Guid UNIQUE NONCLUSTERED (Guid ASC)
		,CONSTRAINT UQ_AssistantWorkflowTemplates_Code UNIQUE NONCLUSTERED (Code ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantWorkflowRuns', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantWorkflowRuns (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,UserId INT NOT NULL
		,WorkflowTemplateId INT NOT NULL
		,ConversationId INT NULL
		,StatusCode NVARCHAR(30) NOT NULL
		,InputJson NVARCHAR(MAX) NULL
		,OutputJson NVARCHAR(MAX) NULL
		,StartedUtc DATETIME2(7) NOT NULL
		,CompletedUtc DATETIME2(7) NULL
		,CONSTRAINT PK_AssistantWorkflowRuns PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantWorkflowRuns_Guid UNIQUE NONCLUSTERED (Guid ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantWorkflowRunSteps', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantWorkflowRunSteps (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,WorkflowRunId INT NOT NULL
		,StepOrder INT NOT NULL
		,Title NVARCHAR(250) NOT NULL
		,InstructionMarkdown NVARCHAR(MAX) NOT NULL
		,StatusCode NVARCHAR(30) NOT NULL
		,CompletedUtc DATETIME2(7) NULL
		,CONSTRAINT PK_AssistantWorkflowRunSteps PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantWorkflowRunSteps_Guid UNIQUE NONCLUSTERED (Guid ASC)
		,CONSTRAINT UQ_AssistantWorkflowRunSteps_RunOrder UNIQUE NONCLUSTERED (
			WorkflowRunId ASC
			,StepOrder ASC
			)
		);
END;

IF OBJECT_ID(N'SAi.AssistantFeedback', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantFeedback (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,UserId INT NOT NULL
		,ConversationId INT NOT NULL
		,MessageId INT NOT NULL
		,FeedbackCode NVARCHAR(20) NOT NULL
		,Comment NVARCHAR(MAX) NULL
		,CreatedUtc DATETIME2(7) NOT NULL
		,CONSTRAINT PK_AssistantFeedback PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantFeedback_Guid UNIQUE NONCLUSTERED (Guid ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantAnalyticsEvents', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantAnalyticsEvents (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,UserId INT NULL
		,ConversationId INT NULL
		,EventTypeCode NVARCHAR(50) NOT NULL
		,EventUtc DATETIME2(7) NOT NULL
		,TopicText NVARCHAR(1000) NULL
		,PayloadJson NVARCHAR(MAX) NULL
		,SuccessFlag BIT NULL
		,CONSTRAINT PK_AssistantAnalyticsEvents PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantAnalyticsEvents_Guid UNIQUE NONCLUSTERED (Guid ASC)
		);
END;

IF OBJECT_ID(N'SAi.AssistantContentGaps', N'U') IS NULL
BEGIN
	CREATE TABLE SAi.AssistantContentGaps (
		ID INT IDENTITY(1, 1) NOT NULL
		,RowStatus TINYINT NOT NULL
		,ROWVERSION ROWVERSION NOT NULL
		,Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
		,Title NVARCHAR(500) NOT NULL
		,Description NVARCHAR(MAX) NULL
		,TopicCluster NVARCHAR(250) NULL
		,OccurrenceCount INT NOT NULL
		,LastSeenUtc DATETIME2(7) NOT NULL
		,StatusCode NVARCHAR(30) NOT NULL
		,SuggestedKnowledgeItemId INT NULL
		,CONSTRAINT PK_AssistantContentGaps PRIMARY KEY CLUSTERED (ID ASC)
		,CONSTRAINT UQ_AssistantContentGaps_Guid UNIQUE NONCLUSTERED (Guid ASC)
		);
END;

/* =========================================================================================
       5. Foreign keys - dataobjects first, then core relations
    ========================================================================================= */
IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantConversations_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantConversations
		WITH CHECK ADD CONSTRAINT FK_AssistantConversations_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantMessages_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantMessages
		WITH CHECK ADD CONSTRAINT FK_AssistantMessages_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantBookmarks_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantBookmarks
		WITH CHECK ADD CONSTRAINT FK_AssistantBookmarks_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantPlaybooks_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantPlaybooks
		WITH CHECK ADD CONSTRAINT FK_AssistantPlaybooks_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantPlaybookSteps_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantPlaybookSteps
		WITH CHECK ADD CONSTRAINT FK_AssistantPlaybookSteps_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeCategories_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantKnowledgeCategories
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeCategories_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeTags_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantKnowledgeTags
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeTags_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItems_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantKnowledgeItems
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItems_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItemVersions_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantKnowledgeItemVersions
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItemVersions_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItemTags_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantKnowledgeItemTags
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItemTags_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantUploads_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantUploads
		WITH CHECK ADD CONSTRAINT FK_AssistantUploads_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantWorkflowTemplates_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantWorkflowTemplates
		WITH CHECK ADD CONSTRAINT FK_AssistantWorkflowTemplates_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantWorkflowRuns_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantWorkflowRuns
		WITH CHECK ADD CONSTRAINT FK_AssistantWorkflowRuns_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantWorkflowRunSteps_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantWorkflowRunSteps
		WITH CHECK ADD CONSTRAINT FK_AssistantWorkflowRunSteps_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantFeedback_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantFeedback
		WITH CHECK ADD CONSTRAINT FK_AssistantFeedback_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantAnalyticsEvents_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantAnalyticsEvents
		WITH CHECK ADD CONSTRAINT FK_AssistantAnalyticsEvents_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantContentGaps_DataObjects'
		)
BEGIN
	ALTER TABLE SAi.AssistantContentGaps
		WITH CHECK ADD CONSTRAINT FK_AssistantContentGaps_DataObjects FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);
END;

/* RowStatus FKs */
IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantConversations_RowStatus'
		)
	ALTER TABLE SAi.AssistantConversations
		WITH CHECK ADD CONSTRAINT FK_AssistantConversations_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantMessages_RowStatus'
		)
	ALTER TABLE SAi.AssistantMessages
		WITH CHECK ADD CONSTRAINT FK_AssistantMessages_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantBookmarks_RowStatus'
		)
	ALTER TABLE SAi.AssistantBookmarks
		WITH CHECK ADD CONSTRAINT FK_AssistantBookmarks_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantPlaybooks_RowStatus'
		)
	ALTER TABLE SAi.AssistantPlaybooks
		WITH CHECK ADD CONSTRAINT FK_AssistantPlaybooks_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantPlaybookSteps_RowStatus'
		)
	ALTER TABLE SAi.AssistantPlaybookSteps
		WITH CHECK ADD CONSTRAINT FK_AssistantPlaybookSteps_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeCategories_RowStatus'
		)
	ALTER TABLE SAi.AssistantKnowledgeCategories
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeCategories_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeTags_RowStatus'
		)
	ALTER TABLE SAi.AssistantKnowledgeTags
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeTags_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItems_RowStatus'
		)
	ALTER TABLE SAi.AssistantKnowledgeItems
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItems_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItemVersions_RowStatus'
		)
	ALTER TABLE SAi.AssistantKnowledgeItemVersions
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItemVersions_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItemTags_RowStatus'
		)
	ALTER TABLE SAi.AssistantKnowledgeItemTags
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItemTags_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantUploads_RowStatus'
		)
	ALTER TABLE SAi.AssistantUploads
		WITH CHECK ADD CONSTRAINT FK_AssistantUploads_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantWorkflowTemplates_RowStatus'
		)
	ALTER TABLE SAi.AssistantWorkflowTemplates
		WITH CHECK ADD CONSTRAINT FK_AssistantWorkflowTemplates_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantWorkflowRuns_RowStatus'
		)
	ALTER TABLE SAi.AssistantWorkflowRuns
		WITH CHECK ADD CONSTRAINT FK_AssistantWorkflowRuns_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantWorkflowRunSteps_RowStatus'
		)
	ALTER TABLE SAi.AssistantWorkflowRunSteps
		WITH CHECK ADD CONSTRAINT FK_AssistantWorkflowRunSteps_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantFeedback_RowStatus'
		)
	ALTER TABLE SAi.AssistantFeedback
		WITH CHECK ADD CONSTRAINT FK_AssistantFeedback_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantAnalyticsEvents_RowStatus'
		)
	ALTER TABLE SAi.AssistantAnalyticsEvents
		WITH CHECK ADD CONSTRAINT FK_AssistantAnalyticsEvents_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantContentGaps_RowStatus'
		)
	ALTER TABLE SAi.AssistantContentGaps
		WITH CHECK ADD CONSTRAINT FK_AssistantContentGaps_RowStatus FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

/* Identity/user FKs */
IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantConversations_Identities_User'
		)
	ALTER TABLE SAi.AssistantConversations
		WITH CHECK ADD CONSTRAINT FK_AssistantConversations_Identities_User FOREIGN KEY (UserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantMessages_Identities_User'
		)
	ALTER TABLE SAi.AssistantMessages
		WITH CHECK ADD CONSTRAINT FK_AssistantMessages_Identities_User FOREIGN KEY (UserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantBookmarks_Identities_User'
		)
	ALTER TABLE SAi.AssistantBookmarks
		WITH CHECK ADD CONSTRAINT FK_AssistantBookmarks_Identities_User FOREIGN KEY (UserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantPlaybooks_Identities_User'
		)
	ALTER TABLE SAi.AssistantPlaybooks
		WITH CHECK ADD CONSTRAINT FK_AssistantPlaybooks_Identities_User FOREIGN KEY (UserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantPlaybooks_Identities_CreatedBy'
		)
	ALTER TABLE SAi.AssistantPlaybooks
		WITH CHECK ADD CONSTRAINT FK_AssistantPlaybooks_Identities_CreatedBy FOREIGN KEY (CreatedByUserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItems_Identities_CreatedBy'
		)
	ALTER TABLE SAi.AssistantKnowledgeItems
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItems_Identities_CreatedBy FOREIGN KEY (CreatedByUserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItems_Identities_UpdatedBy'
		)
	ALTER TABLE SAi.AssistantKnowledgeItems
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItems_Identities_UpdatedBy FOREIGN KEY (UpdatedByUserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItemVersions_Identities_CreatedBy'
		)
	ALTER TABLE SAi.AssistantKnowledgeItemVersions
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItemVersions_Identities_CreatedBy FOREIGN KEY (CreatedByUserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantUploads_Identities_User'
		)
	ALTER TABLE SAi.AssistantUploads
		WITH CHECK ADD CONSTRAINT FK_AssistantUploads_Identities_User FOREIGN KEY (UserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantWorkflowTemplates_Identities_CreatedBy'
		)
	ALTER TABLE SAi.AssistantWorkflowTemplates
		WITH CHECK ADD CONSTRAINT FK_AssistantWorkflowTemplates_Identities_CreatedBy FOREIGN KEY (CreatedByUserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantWorkflowRuns_Identities_User'
		)
	ALTER TABLE SAi.AssistantWorkflowRuns
		WITH CHECK ADD CONSTRAINT FK_AssistantWorkflowRuns_Identities_User FOREIGN KEY (UserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantFeedback_Identities_User'
		)
	ALTER TABLE SAi.AssistantFeedback
		WITH CHECK ADD CONSTRAINT FK_AssistantFeedback_Identities_User FOREIGN KEY (UserId) REFERENCES SCore.Identities(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantAnalyticsEvents_Identities_User'
		)
	ALTER TABLE SAi.AssistantAnalyticsEvents
		WITH CHECK ADD CONSTRAINT FK_AssistantAnalyticsEvents_Identities_User FOREIGN KEY (UserId) REFERENCES SCore.Identities(ID);

/* Core relational FKs */
IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantMessages_Conversations'
		)
	ALTER TABLE SAi.AssistantMessages
		WITH CHECK ADD CONSTRAINT FK_AssistantMessages_Conversations FOREIGN KEY (ConversationId) REFERENCES SAi.AssistantConversations(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantMessages_ParentMessage'
		)
	ALTER TABLE SAi.AssistantMessages
		WITH CHECK ADD CONSTRAINT FK_AssistantMessages_ParentMessage FOREIGN KEY (ParentMessageId) REFERENCES SAi.AssistantMessages(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantBookmarks_Conversations'
		)
	ALTER TABLE SAi.AssistantBookmarks
		WITH CHECK ADD CONSTRAINT FK_AssistantBookmarks_Conversations FOREIGN KEY (ConversationId) REFERENCES SAi.AssistantConversations(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantBookmarks_Messages'
		)
	ALTER TABLE SAi.AssistantBookmarks
		WITH CHECK ADD CONSTRAINT FK_AssistantBookmarks_Messages FOREIGN KEY (MessageId) REFERENCES SAi.AssistantMessages(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantPlaybookSteps_Playbooks'
		)
	ALTER TABLE SAi.AssistantPlaybookSteps
		WITH CHECK ADD CONSTRAINT FK_AssistantPlaybookSteps_Playbooks FOREIGN KEY (PlaybookId) REFERENCES SAi.AssistantPlaybooks(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItems_Categories'
		)
	ALTER TABLE SAi.AssistantKnowledgeItems
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItems_Categories FOREIGN KEY (KnowledgeCategoryId) REFERENCES SAi.AssistantKnowledgeCategories(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItemVersions_Items'
		)
	ALTER TABLE SAi.AssistantKnowledgeItemVersions
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItemVersions_Items FOREIGN KEY (KnowledgeItemId) REFERENCES SAi.AssistantKnowledgeItems(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItemTags_Items'
		)
	ALTER TABLE SAi.AssistantKnowledgeItemTags
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItemTags_Items FOREIGN KEY (KnowledgeItemId) REFERENCES SAi.AssistantKnowledgeItems(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantKnowledgeItemTags_Tags'
		)
	ALTER TABLE SAi.AssistantKnowledgeItemTags
		WITH CHECK ADD CONSTRAINT FK_AssistantKnowledgeItemTags_Tags FOREIGN KEY (KnowledgeTagId) REFERENCES SAi.AssistantKnowledgeTags(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantUploads_Conversations'
		)
	ALTER TABLE SAi.AssistantUploads
		WITH CHECK ADD CONSTRAINT FK_AssistantUploads_Conversations FOREIGN KEY (ConversationId) REFERENCES SAi.AssistantConversations(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantUploads_KnowledgeItems'
		)
	ALTER TABLE SAi.AssistantUploads
		WITH CHECK ADD CONSTRAINT FK_AssistantUploads_KnowledgeItems FOREIGN KEY (KnowledgeItemId) REFERENCES SAi.AssistantKnowledgeItems(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantWorkflowRuns_Templates'
		)
	ALTER TABLE SAi.AssistantWorkflowRuns
		WITH CHECK ADD CONSTRAINT FK_AssistantWorkflowRuns_Templates FOREIGN KEY (WorkflowTemplateId) REFERENCES SAi.AssistantWorkflowTemplates(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantWorkflowRuns_Conversations'
		)
	ALTER TABLE SAi.AssistantWorkflowRuns
		WITH CHECK ADD CONSTRAINT FK_AssistantWorkflowRuns_Conversations FOREIGN KEY (ConversationId) REFERENCES SAi.AssistantConversations(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantWorkflowRunSteps_Runs'
		)
	ALTER TABLE SAi.AssistantWorkflowRunSteps
		WITH CHECK ADD CONSTRAINT FK_AssistantWorkflowRunSteps_Runs FOREIGN KEY (WorkflowRunId) REFERENCES SAi.AssistantWorkflowRuns(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantFeedback_Conversations'
		)
	ALTER TABLE SAi.AssistantFeedback
		WITH CHECK ADD CONSTRAINT FK_AssistantFeedback_Conversations FOREIGN KEY (ConversationId) REFERENCES SAi.AssistantConversations(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantFeedback_Messages'
		)
	ALTER TABLE SAi.AssistantFeedback
		WITH CHECK ADD CONSTRAINT FK_AssistantFeedback_Messages FOREIGN KEY (MessageId) REFERENCES SAi.AssistantMessages(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantAnalyticsEvents_Conversations'
		)
	ALTER TABLE SAi.AssistantAnalyticsEvents
		WITH CHECK ADD CONSTRAINT FK_AssistantAnalyticsEvents_Conversations FOREIGN KEY (ConversationId) REFERENCES SAi.AssistantConversations(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantContentGaps_KnowledgeItems'
		)
	ALTER TABLE SAi.AssistantContentGaps
		WITH CHECK ADD CONSTRAINT FK_AssistantContentGaps_KnowledgeItems FOREIGN KEY (SuggestedKnowledgeItemId) REFERENCES SAi.AssistantKnowledgeItems(ID);

/* Late-bound circular FKs */
IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantConversations_WorkflowTemplate'
		)
	ALTER TABLE SAi.AssistantConversations
		WITH CHECK ADD CONSTRAINT FK_AssistantConversations_WorkflowTemplate FOREIGN KEY (StartedFromWorkflowTemplateId) REFERENCES SAi.AssistantWorkflowTemplates(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantConversations_LastMessage'
		)
	ALTER TABLE SAi.AssistantConversations
		WITH CHECK ADD CONSTRAINT FK_AssistantConversations_LastMessage FOREIGN KEY (LastMessageId) REFERENCES SAi.AssistantMessages(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantPlaybooks_SourceConversation'
		)
	ALTER TABLE SAi.AssistantPlaybooks
		WITH CHECK ADD CONSTRAINT FK_AssistantPlaybooks_SourceConversation FOREIGN KEY (SourceConversationId) REFERENCES SAi.AssistantConversations(ID);

IF NOT EXISTS (
		SELECT 1
		FROM sys.foreign_keys
		WHERE name = N'FK_AssistantPlaybooks_SourceWorkflowRun'
		)
	ALTER TABLE SAi.AssistantPlaybooks
		WITH CHECK ADD CONSTRAINT FK_AssistantPlaybooks_SourceWorkflowRun FOREIGN KEY (SourceWorkflowRunId) REFERENCES SAi.AssistantWorkflowRuns(ID);

/* =========================================================================================
       6. Supporting indexes
    ========================================================================================= */
IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantConversations_User_LastActivity'
			AND object_id = OBJECT_ID(N'SAi.AssistantConversations')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantConversations_User_LastActivity ON SAi.AssistantConversations (
		UserId ASC
		,LastActivityUtc DESC
		) INCLUDE (
		Title
		,ModeCode
		,IsArchived
		,IsPinned
		);

IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantMessages_Conversation_CreatedUtc'
			AND object_id = OBJECT_ID(N'SAi.AssistantMessages')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantMessages_Conversation_CreatedUtc ON SAi.AssistantMessages (
		ConversationId ASC
		,CreatedUtc ASC
		) INCLUDE (
		MessageRoleCode
		,AnswerTypeCode
		,ConfidenceScore
		);

IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantBookmarks_User_CreatedUtc'
			AND object_id = OBJECT_ID(N'SAi.AssistantBookmarks')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantBookmarks_User_CreatedUtc ON SAi.AssistantBookmarks (
		UserId ASC
		,CreatedUtc DESC
		) INCLUDE (
		ConversationId
		,MessageId
		,Title
		);

IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantPlaybooks_User_UpdatedUtc'
			AND object_id = OBJECT_ID(N'SAi.AssistantPlaybooks')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantPlaybooks_User_UpdatedUtc ON SAi.AssistantPlaybooks (
		UserId ASC
		,UpdatedUtc DESC
		) INCLUDE (
		Title
		,VisibilityCode
		,IsFeatured
		,PlaybookTypeCode
		);

IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantKnowledgeItems_Category_Published'
			AND object_id = OBJECT_ID(N'SAi.AssistantKnowledgeItems')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantKnowledgeItems_Category_Published ON SAi.AssistantKnowledgeItems (
		KnowledgeCategoryId ASC
		,IsPublished ASC
		,IsAuthoritative ASC
		) INCLUDE (
		Title
		,Slug
		,ContentTypeCode
		,UpdatedUtc
		);

IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantKnowledgeItemVersions_Item_Current'
			AND object_id = OBJECT_ID(N'SAi.AssistantKnowledgeItemVersions')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantKnowledgeItemVersions_Item_Current ON SAi.AssistantKnowledgeItemVersions (
		KnowledgeItemId ASC
		,IsCurrent DESC
		,VersionNumber DESC
		) INCLUDE (
		ExtractionStatusCode
		,CreatedUtc
		);

IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantUploads_User_CreatedUtc'
			AND object_id = OBJECT_ID(N'SAi.AssistantUploads')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantUploads_User_CreatedUtc ON SAi.AssistantUploads (
		UserId ASC
		,CreatedUtc DESC
		) INCLUDE (
		ConversationId
		,KnowledgeItemId
		,UploadPurposeCode
		,ProcessingStatusCode
		,FileName
		);

IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantWorkflowTemplates_Published_Featured'
			AND object_id = OBJECT_ID(N'SAi.AssistantWorkflowTemplates')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantWorkflowTemplates_Published_Featured ON SAi.AssistantWorkflowTemplates (
		IsPublished ASC
		,IsFeatured DESC
		,AudienceCode ASC
		) INCLUDE (
		Code
		,Title
		,OutputFormatCode
		);

IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantWorkflowRuns_User_StartedUtc'
			AND object_id = OBJECT_ID(N'SAi.AssistantWorkflowRuns')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantWorkflowRuns_User_StartedUtc ON SAi.AssistantWorkflowRuns (
		UserId ASC
		,StartedUtc DESC
		) INCLUDE (
		WorkflowTemplateId
		,StatusCode
		,ConversationId
		);

IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantFeedback_Message'
			AND object_id = OBJECT_ID(N'SAi.AssistantFeedback')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantFeedback_Message ON SAi.AssistantFeedback (
		MessageId ASC
		,CreatedUtc DESC
		) INCLUDE (
		FeedbackCode
		,UserId
		,ConversationId
		);

IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantAnalyticsEvents_EventUtc_Type'
			AND object_id = OBJECT_ID(N'SAi.AssistantAnalyticsEvents')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantAnalyticsEvents_EventUtc_Type ON SAi.AssistantAnalyticsEvents (
		EventUtc DESC
		,EventTypeCode ASC
		) INCLUDE (
		UserId
		,ConversationId
		,SuccessFlag
		,TopicText
		);

IF NOT EXISTS (
		SELECT 1
		FROM sys.indexes
		WHERE name = N'IX_AssistantContentGaps_Status_LastSeen'
			AND object_id = OBJECT_ID(N'SAi.AssistantContentGaps')
		)
	CREATE NONCLUSTERED INDEX IX_AssistantContentGaps_Status_LastSeen ON SAi.AssistantContentGaps (
		StatusCode ASC
		,LastSeenUtc DESC
		) INCLUDE (
		Title
		,TopicCluster
		,OccurrenceCount
		,SuggestedKnowledgeItemId
		);
GO

/* =========================================================================================
       7. Helper procedures to create DataObjects-backed rows for SAi entities
          These are foundational and can be reused by later CRUD/upsert procedures.
    ========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.Assistant_CreateDataObject (
	@Guid UNIQUEIDENTIFIER
	,@EntityTypeId INT
	,@RowStatus TINYINT = 1
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ExistingEntityTypeId INT;

	SELECT @ExistingEntityTypeId = d.EntityTypeId
	FROM SCore.DataObjects AS d
	WHERE d.Guid = @Guid;

	IF @ExistingEntityTypeId IS NOT NULL
	BEGIN
		IF @ExistingEntityTypeId <> @EntityTypeId
		BEGIN
				;

			THROW 60010
				,N'Existing SCore.DataObjects row has a different EntityTypeId.'
				,1;
		END;

		RETURN;
	END;

	INSERT INTO SCore.DataObjects (
		Guid
		,RowStatus
		,EntityTypeId
		)
	VALUES (
		@Guid
		,@RowStatus
		,@EntityTypeId
		);
END;
GO

CREATE
	OR

ALTER FUNCTION SAi.Assistant_ResolveEntityTypeId (@EntityName NVARCHAR(250))
RETURNS INT
AS
BEGIN
	DECLARE @Id INT;

	SELECT @Id = et.ID
	FROM SCore.EntityTypes AS et
	WHERE et.Name = @EntityName
		AND et.RowStatus NOT IN (
			0
			,254
			);

	RETURN ISNULL(@Id, - 1);
END;
GO

/* =========================================================================================
       8. Seed baseline knowledge categories for MVP usability
    ========================================================================================= */
BEGIN
	DECLARE @Et_AssistantKnowledgeCategories INT;

	SELECT @Et_AssistantKnowledgeCategories = et.ID
	FROM SCore.EntityTypes AS et
	WHERE et.Guid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000008'
	  AND et.RowStatus NOT IN (0, 254);

	IF @Et_AssistantKnowledgeCategories IS NULL
	BEGIN
		;THROW 60002, N'Assistant Knowledge Categories EntityType could not be resolved for category seed.', 1;
	END;
	DECLARE @SeedKnowledgeCategories TABLE (
		EntityGuid UNIQUEIDENTIFIER NOT NULL
		,[Name] NVARCHAR(250) NOT NULL
		,Code NVARCHAR(50) NOT NULL
		,[Description] NVARCHAR(1000) NULL
		,DisplayOrder INT NOT NULL
		);

	INSERT INTO @SeedKnowledgeCategories (
		EntityGuid
		,[Name]
		,Code
		,[Description]
		,DisplayOrder
		)
	VALUES (
		'9C87EFA0-0A5C-4A49-9AF5-9B5AF2200001'
		,N'Getting Started'
		,N'GETTING_STARTED'
		,N'Introductory setup and first-use help.'
		,10
		)
		,(
		'9C87EFA0-0A5C-4A49-9AF5-9B5AF2200002'
		,N'Workflows'
		,N'WORKFLOWS'
		,N'Guides for common CymBuild processes and journeys.'
		,20
		)
		,(
		'9C87EFA0-0A5C-4A49-9AF5-9B5AF2200003'
		,N'Troubleshooting'
		,N'TROUBLESHOOTING'
		,N'Known issues, diagnostics, and fix steps.'
		,30
		)
		,(
		'9C87EFA0-0A5C-4A49-9AF5-9B5AF2200004'
		,N'Permissions'
		,N'PERMISSIONS'
		,N'Access, roles, and security guidance.'
		,40
		)
		,(
		'9C87EFA0-0A5C-4A49-9AF5-9B5AF2200005'
		,N'Reporting'
		,N'REPORTING'
		,N'Reports, metrics, and export guidance.'
		,50
		)
		,(
		'9C87EFA0-0A5C-4A49-9AF5-9B5AF2200006'
		,N'Finance'
		,N'FINANCE'
		,N'Finance, invoice, and billing assistant knowledge.'
		,60
		)
		,(
		'9C87EFA0-0A5C-4A49-9AF5-9B5AF2200007'
		,N'Admin'
		,N'ADMIN'
		,N'Administrative and configuration guidance.'
		,70
		);

	DECLARE @CategoryGuid UNIQUEIDENTIFIER;
	DECLARE @CategoryName NVARCHAR(250);
	DECLARE @CategoryCode NVARCHAR(50);
	DECLARE @CategoryDescription NVARCHAR(1000);
	DECLARE @CategoryDisplayOrder INT;

	DECLARE Cur_AssistantKnowledgeCategory CURSOR LOCAL FAST_FORWARD
	FOR
	SELECT EntityGuid
		,[Name]
		,Code
		,[Description]
		,DisplayOrder
	FROM @SeedKnowledgeCategories;

	OPEN Cur_AssistantKnowledgeCategory;

	FETCH NEXT
	FROM Cur_AssistantKnowledgeCategory
	INTO @CategoryGuid
		,@CategoryName
		,@CategoryCode
		,@CategoryDescription
		,@CategoryDisplayOrder;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM SAi.AssistantKnowledgeCategories c
				WHERE c.Guid = @CategoryGuid
				)
		BEGIN
			EXEC SAi.Assistant_CreateDataObject @Guid = @CategoryGuid
				,@EntityTypeId = @Et_AssistantKnowledgeCategories
				,@RowStatus = 1;

			INSERT SAi.AssistantKnowledgeCategories (
				RowStatus
				,Guid
				,Name
				,Code
				,Description
				,DisplayOrder
				,IsVisible
				)
			VALUES (
				1
				,@CategoryGuid
				,@CategoryName
				,@CategoryCode
				,@CategoryDescription
				,@CategoryDisplayOrder
				,1
				);
		END;

		FETCH NEXT
		FROM Cur_AssistantKnowledgeCategory
		INTO @CategoryGuid
			,@CategoryName
			,@CategoryCode
			,@CategoryDescription
			,@CategoryDisplayOrder;
	END;

	CLOSE Cur_AssistantKnowledgeCategory;

	DEALLOCATE Cur_AssistantKnowledgeCategory;
END;
GO

/*
    9. CRUD / Upsert / Read Layer
    ----------------------------
    Adds the first usable persistence and read surface for SAi.
*/
/* =========================================================================================
   9.1 Conversation create / upsert
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.AssistantConversationUpsert (
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

/* =========================================================================================
   9.2 Message create
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.AssistantMessageCreate (
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

/* =========================================================================================
   9.3 Bookmark upsert
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.AssistantBookmarkUpsert (
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

/* =========================================================================================
   9.4 Knowledge item upsert
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.AssistantKnowledgeItemUpsert (
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

/* =========================================================================================
   9.5 Knowledge version create
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.AssistantKnowledgeItemVersionCreate (
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

/* =========================================================================================
   9.6 Workflow template upsert
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.AssistantWorkflowTemplateUpsert (
	@Code NVARCHAR(50)
	,@Title NVARCHAR(250)
	,@Summary NVARCHAR(1000) = NULL
	,@AudienceCode NVARCHAR(30) = NULL
	,@TemplatePrompt NVARCHAR(MAX)
	,@ClarificationSchemaJson NVARCHAR(MAX) = NULL
	,@OutputFormatCode NVARCHAR(30)
	,@IsPublished BIT = 0
	,@IsFeatured BIT = 0
	,@CreatedByUserId INT
	,@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @IsInsert BIT = 0;
	DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();

	EXEC SCore.UpsertDataObject @Guid = @Guid
		,@SchemeName = N'SAi'
		,@ObjectName = N'AssistantWorkflowTemplates'
		,@IsInsert = @IsInsert OUTPUT;

	IF (@IsInsert = 1)
	BEGIN
		INSERT SAi.AssistantWorkflowTemplates (
			Guid
			,RowStatus
			,Code
			,Title
			,Summary
			,AudienceCode
			,TemplatePrompt
			,ClarificationSchemaJson
			,OutputFormatCode
			,IsPublished
			,IsFeatured
			,CreatedByUserId
			,CreatedUtc
			,UpdatedUtc
			)
		VALUES (
			@Guid
			,1
			,@Code
			,@Title
			,@Summary
			,@AudienceCode
			,@TemplatePrompt
			,@ClarificationSchemaJson
			,@OutputFormatCode
			,@IsPublished
			,@IsFeatured
			,@CreatedByUserId
			,@NowUtc
			,NULL
			);
	END
	ELSE
	BEGIN
		UPDATE SAi.AssistantWorkflowTemplates
		SET RowStatus = 1
			,Code = @Code
			,Title = @Title
			,Summary = @Summary
			,AudienceCode = @AudienceCode
			,TemplatePrompt = @TemplatePrompt
			,ClarificationSchemaJson = @ClarificationSchemaJson
			,OutputFormatCode = @OutputFormatCode
			,IsPublished = @IsPublished
			,IsFeatured = @IsFeatured
			,UpdatedUtc = @NowUtc
		WHERE Guid = @Guid;
	END;
END;
GO

/* =========================================================================================
   9.7 Workflow run upsert
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.AssistantWorkflowRunUpsert (
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

/* =========================================================================================
   9.8 Upload create
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.AssistantUploadCreate (
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

/* =========================================================================================
   9.9 Feedback create
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.AssistantFeedbackCreate (
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

/* =========================================================================================
   9.10 Analytics event create
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.AssistantAnalyticsEventCreate (
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

/* =========================================================================================
   9.11 Content gap upsert
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.AssistantContentGapUpsert (
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

/* =========================================================================================
       9.12 Read TVFs / Views
    ========================================================================================= */
CREATE
	OR

ALTER FUNCTION SAi.tvf_AssistantConversationList (@UserId INT)
RETURNS TABLE
AS
RETURN (
		SELECT c.ID
			,c.Guid
			,c.UserId
			,c.Title
			,c.ModeCode
			,c.LanguageCode
			,c.LastActivityUtc
			,c.IsPinned
			,c.IsArchived
			,c.StartedFromWorkflowTemplateId
			,c.LastMessageId
			,m.ContentPlainText AS LastMessagePlainText
			,m.ContentMarkdown AS LastMessageMarkdown
			,m.MessageRoleCode AS LastMessageRoleCode
			,m.CreatedUtc AS LastMessageCreatedUtc
		FROM SAi.AssistantConversations AS c
		LEFT JOIN SAi.AssistantMessages AS m ON m.ID = c.LastMessageId
			AND m.RowStatus NOT IN (
				0
				,254
				)
		WHERE c.UserId = @UserId
			AND c.RowStatus NOT IN (
				0
				,254
				)
		);
GO

CREATE
	OR

ALTER FUNCTION SAi.tvf_AssistantConversationMessages (@ConversationGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN (
		SELECT m.ID
			,m.Guid
			,c.Guid AS ConversationGuid
			,m.UserId
			,m.MessageRoleCode
			,m.AnswerTypeCode
			,m.ContentMarkdown
			,m.ContentPlainText
			,m.SourcePayloadJson
			,m.FollowUpPayloadJson
			,m.ConfidenceScore
			,m.CreatedUtc
			,m.PromptTokens
			,m.CompletionTokens
			,m.ModelCode
			,m.ParentMessageId
		FROM SAi.AssistantMessages m
		JOIN SAi.AssistantConversations c ON c.ID = m.ConversationId
		WHERE c.Guid = @ConversationGuid
			AND c.RowStatus NOT IN (
				0
				,254
				)
			AND m.RowStatus NOT IN (
				0
				,254
				)
		);
GO

CREATE
	OR

ALTER FUNCTION SAi.tvf_AssistantKnowledgeSearch (@SearchText NVARCHAR(500))
RETURNS TABLE
AS
RETURN (
		SELECT ki.ID
			,ki.Guid
			,ki.Title
			,ki.Slug
			,kc.Name AS CategoryName
			,kc.Code AS CategoryCode
			,ki.ContentTypeCode
			,ki.SourceTypeCode
			,ki.StorageUrl
			,ki.PreviewUrl
			,ki.Summary
			,ki.IsAuthoritative
			,ki.IsPublished
			,ki.PublishedUtc
			,ki.CreatedUtc
			,ki.UpdatedUtc
			,kv.VersionNumber
			,kv.ExtractionStatusCode
			,kv.ExtractedText
		FROM SAi.AssistantKnowledgeItems ki
		LEFT JOIN SAi.AssistantKnowledgeCategories kc ON kc.ID = ki.KnowledgeCategoryId
		OUTER APPLY (
			SELECT TOP (1) v.VersionNumber
				,v.ExtractionStatusCode
				,v.ExtractedText
			FROM SAi.AssistantKnowledgeItemVersions v
			WHERE v.KnowledgeItemId = ki.ID
				AND v.RowStatus NOT IN (
					0
					,254
					)
				AND v.IsCurrent = 1
			ORDER BY v.VersionNumber DESC
			) kv
		WHERE ki.RowStatus NOT IN (
				0
				,254
				)
			AND ki.IsPublished = 1
			AND (
				@SearchText = N''
				OR ki.Title LIKE N' % ' + @SearchText + N' % '
				OR ISNULL(ki.Summary, N'') LIKE N' % ' + @SearchText + N' % '
				OR ISNULL(kv.ExtractedText, N'') LIKE N' % ' + @SearchText + N' % '
				)
		);
GO

CREATE
	OR

ALTER VIEW SAi.vw_AssistantAdminDashboard
AS
SELECT (
		SELECT COUNT(1)
		FROM SAi.AssistantConversations AS c
		WHERE c.RowStatus NOT IN (
				0
				,254
				)
		) AS TotalConversations
	,(
		SELECT COUNT(1)
		FROM SAi.AssistantMessages AS m
		WHERE m.RowStatus NOT IN (
				0
				,254
				)
		) AS TotalMessages
	,(
		SELECT COUNT(1)
		FROM SAi.AssistantKnowledgeItems AS ki
		WHERE ki.RowStatus NOT IN (
				0
				,254
				)
			AND ki.IsPublished = 1
		) AS PublishedKnowledgeItems
	,(
		SELECT COUNT(1)
		FROM SAi.AssistantWorkflowTemplates AS wt
		WHERE wt.RowStatus NOT IN (
				0
				,254
				)
			AND wt.IsPublished = 1
		) AS PublishedWorkflowTemplates
	,(
		SELECT COUNT(1)
		FROM SAi.AssistantFeedback AS f
		WHERE f.RowStatus NOT IN (
				0
				,254
				)
			AND f.FeedbackCode = N'unhelpful'
		) AS UnhelpfulFeedbackCount
	,(
		SELECT COUNT(1)
		FROM SAi.AssistantContentGaps AS g
		WHERE g.RowStatus NOT IN (
				0
				,254
				)
			AND g.StatusCode IN (
				N'new'
				,N'reviewing'
				,N'assigned'
				)
		) AS OpenContentGapCount;
GO

/*
        10. Metadata / Admin UI Seed Layer
        ---------------------------------
        Seeds SUserInterface metadata for SAi admin grids.

        NOTES
        -----
        - Uses the real CymBuild metadata hierarchy:
            GridDefinitions -> GridViewDefinitions -> GridViewColumnDefinitions.
        - GridDefinitions and GridViewDefinitions are DataObject-backed metadata tables.
        - GridViewDefinitionUpsert auto-creates hidden ID/Guid columns on insert. fileciteturn7file0
        - GridDefinition / GridView / Grid column records ultimately link to SCore.DataObjects and SCore.LanguageLabels. fileciteturn6file8turn6file17
    */
/* =========================================================================================
   10.1 Helpers for metadata seeding
========================================================================================= */
CREATE
	OR

ALTER PROCEDURE SAi.Assistant_EnsureLanguageLabel (
	@Name NVARCHAR(250)
	,@Guid UNIQUEIDENTIFIER OUTPUT
	)
AS
BEGIN
	SET NOCOUNT ON;

	EXEC SCore.LanguageLabelUpsert @Name = @Name
		,@Guid = @Guid OUTPUT;
END;
GO

CREATE
	OR

ALTER FUNCTION SAi.Assistant_ResolveGridViewTypeGuid (@Name NVARCHAR(50))
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @Guid UNIQUEIDENTIFIER;

	SELECT @Guid = gvt.Guid
	FROM SUserInterface.GridViewTypes gvt
	WHERE gvt.Name = @Name
		AND gvt.RowStatus NOT IN (
			0
			,254
			);

	RETURN @Guid;
END;
GO

CREATE
	OR

ALTER FUNCTION SAi.Assistant_ResolveAnyIconGuid ()
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @Guid UNIQUEIDENTIFIER;

	SELECT TOP (1) @Guid = i.Guid
	FROM SUserInterface.Icons i
	WHERE i.RowStatus NOT IN (
			0
			,254
			)
	ORDER BY i.ID;

	RETURN @Guid;
END;
GO

CREATE
	OR

ALTER PROCEDURE SAi.Assistant_EnsureGridDefinition (
	@Code NVARCHAR(20)
	,@Name NVARCHAR(100)
	,@PageUri NVARCHAR(200)
	,@TabName NVARCHAR(100)
	,@Guid UNIQUEIDENTIFIER
	,@LanguageLabelGuid UNIQUEIDENTIFIER
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	EXEC SCore.LanguageLabelUpsert @Name = @Name
		,@Guid = @LanguageLabelGuid OUTPUT;

	EXEC SUserInterface.GridDefinitionUpsert @Code = @Code
		,@RowStatus = 1
		,@TabName = @TabName
		,@ShowAsTiles = 0
		,@PageUri = @PageUri
		,@LanguageLabelGuid = @LanguageLabelGuid
		,@Guid = @Guid OUTPUT;
END;
GO

CREATE
	OR

ALTER PROCEDURE SAi.Assistant_EnsureGridViewDefinition (
	@Code NVARCHAR(20)
	,@GridDefinitionGuid UNIQUEIDENTIFIER
	,@DetailPageUri NVARCHAR(250)
	,@SqlQuery NVARCHAR(MAX)
	,@DefaultSortColumnName NVARCHAR(250)
	,@DisplayOrder INT
	,@DisplayGroupName NVARCHAR(50)
	,@EntityTypeGuid UNIQUEIDENTIFIER
	,@LanguageLabelGuid UNIQUEIDENTIFIER
	,@Guid UNIQUEIDENTIFIER OUTPUT
	,@ShowOnMobile BIT = 1
	,@SecurableCode NVARCHAR(20) = N''
	,@MetricSqlQuery NVARCHAR(MAX) = N''
	,@ShowMetric BIT = 0
	,@IsDetailWindowed BIT = 0
	,@MetricTypeGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000'
	,@MetricMin INT = 0
	,@MetricMax INT = 0
	,@MetricMinorUnit INT = 0
	,@MetricMajorUnit INT = 0
	,@MetricStartAngle INT = 0
	,@MetricEndAngle INT = 0
	,@MetricReversed BIT = 0
	,@MetricRange1Min DECIMAL(18, 0) = 0
	,@MetricRange1Max DECIMAL(18, 0) = 0
	,@MetricRange1ColourHex NVARCHAR(10) = N''
	,@MetricRange2Min DECIMAL(18, 0) = 0
	,@MetricRange2Max DECIMAL(18, 0) = 0
	,@MetricRange2ColourHex NVARCHAR(10) = N''
	,@IsDefaultSortDescending BIT = 1
	,@AllowNew BIT = 0
	,@AllowExcelExport BIT = 1
	,@AllowPdfExport BIT = 0
	,@AllowCsvExport BIT = 1
	,@AllowBulkChange BIT = 0
	,@ShowOnDashboard BIT = 0
	,@TreeListFirstOrderBy NVARCHAR(100) = N''
	,@TreeListSecondOrderBy NVARCHAR(100) = N''
	,@TreeListThirdOrderBy NVARCHAR(100) = N''
	,@TreeListOrderBy NVARCHAR(100) = N''
	,@TreeListGroupBy NVARCHAR(100) = N''
	,@FilteredListCreatedOnColumn NVARCHAR(100) = N''
	,@FilteredListRedStatusIndicatorTxt NVARCHAR(100) = N''
	,@FilteredListOrangeStatusIndicatorTxt NVARCHAR(100) = N''
	,@FilteredListGreenStatusIndicatorTxt NVARCHAR(100) = N''
	,@FilteredListGroupBy NVARCHAR(100) = N''
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @GridViewTypeGuid UNIQUEIDENTIFIER = SAi.Assistant_ResolveGridViewTypeGuid(N'Grid');
	DECLARE @DrawerIconGuid UNIQUEIDENTIFIER = SAi.Assistant_ResolveAnyIconGuid();

	IF @GridViewTypeGuid IS NULL
	BEGIN
		SELECT TOP (1) @GridViewTypeGuid = gvt.Guid
		FROM SUserInterface.GridViewTypes AS gvt
		WHERE gvt.RowStatus NOT IN (
				0
				,254
				)
		ORDER BY gvt.ID;
	END;

	IF @GridViewTypeGuid IS NULL
	BEGIN
			;

		THROW 60200
			,N'Unable to resolve a GridViewType Guid for metadata seeding.'
			,1;
	END;

	IF @DrawerIconGuid IS NULL
	BEGIN
			;

		THROW 60201
			,N'Unable to resolve an Icon Guid for metadata seeding.'
			,1;
	END;

	EXEC SUserInterface.GridViewDefinitionUpsert @Code = @Code
		,@RowStatus = 1
		,@GridDefinitionGuid = @GridDefinitionGuid
		,@DetailPageUri = @DetailPageUri
		,@SqlQuery = @SqlQuery
		,@DefaultSortColumnName = @DefaultSortColumnName
		,@SecurableCode = @SecurableCode
		,@DisplayOrder = @DisplayOrder
		,@DisplayGroupName = @DisplayGroupName
		,@MetricSqlQuery = @MetricSqlQuery
		,@ShowMetric = @ShowMetric
		,@IsDetailWindowed = @IsDetailWindowed
		,@EntityTypeGuid = @EntityTypeGuid
		,@MetricTypeGuid = @MetricTypeGuid
		,@MetricMin = @MetricMin
		,@MetricMax = @MetricMax
		,@MetricMinorUnit = @MetricMinorUnit
		,@MetricMajorUnit = @MetricMajorUnit
		,@MetricStartAngle = @MetricStartAngle
		,@MetricEndAngle = @MetricEndAngle
		,@MetricReversed = @MetricReversed
		,@MetricRange1Min = @MetricRange1Min
		,@MetricRange1Max = @MetricRange1Max
		,@MetricRange1ColourHex = @MetricRange1ColourHex
		,@MetricRange2Min = @MetricRange2Min
		,@MetricRange2Max = @MetricRange2Max
		,@MetricRange2ColourHex = @MetricRange2ColourHex
		,@IsDefaultSortDescending = @IsDefaultSortDescending
		,@AllowNew = @AllowNew
		,@AllowExcelExport = @AllowExcelExport
		,@AllowPdfExport = @AllowPdfExport
		,@AllowCsvExport = @AllowCsvExport
		,@LanguageLabelGuid = @LanguageLabelGuid
		,@DrawerIconGuid = @DrawerIconGuid
		,@GridViewTypeGuid = @GridViewTypeGuid
		,@AllowBulkChange = @AllowBulkChange
		,@Guid = @Guid OUTPUT
		,@ShowOnMobile = @ShowOnMobile
		,@TreeListFirstOrderBy = @TreeListFirstOrderBy
		,@TreeListSecondOrderBy = @TreeListSecondOrderBy
		,@TreeListThirdOrderBy = @TreeListThirdOrderBy
		,@TreeListOrderBy = @TreeListOrderBy
		,@TreeListGroupBy = @TreeListGroupBy
		,@ShowOnDashboard = @ShowOnDashboard
		,@FilteredListCreatedOnColumn = @FilteredListCreatedOnColumn
		,@FilteredListRedStatusIndicatorTxt = @FilteredListRedStatusIndicatorTxt
		,@FilteredListOrangeStatusIndicatorTxt = @FilteredListOrangeStatusIndicatorTxt
		,@FilteredListGreenStatusIndicatorTxt = @FilteredListGreenStatusIndicatorTxt
		,@FilteredListGroupBy = @FilteredListGroupBy;
END;
GO

CREATE OR ALTER PROCEDURE SAi.Assistant_EnsureGridColumn
(
    @GridViewGuid UNIQUEIDENTIFIER,
    @ColumnGuid UNIQUEIDENTIFIER,
    @Name NVARCHAR(100),
    @ColumnOrder INT,
    @LanguageLabelName NVARCHAR(250),
    @IsPrimaryKey BIT = 0,
    @IsHidden BIT = 0,
    @IsFiltered BIT = 1,
    @IsCombo BIT = 0,
    @IsLongitude BIT = 0,
    @IsLatitude BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @GridViewDefinitionId INT;
    DECLARE @LanguageLabelGuid UNIQUEIDENTIFIER = NEWID();
    DECLARE @LanguageLabelId INT;
    DECLARE @IsInsert BIT;

    SELECT @GridViewDefinitionId = gvd.ID
    FROM SUserInterface.GridViewDefinitions AS gvd
    WHERE gvd.Guid = @GridViewGuid
      AND gvd.RowStatus NOT IN (0,254);

    IF @GridViewDefinitionId IS NULL
    BEGIN
        ;THROW 60210, N'Grid view definition not found for column seed.', 1;
    END;

    EXEC SCore.LanguageLabelUpsert
         @Name = @LanguageLabelName,
         @Guid = @LanguageLabelGuid OUTPUT;

    SELECT @LanguageLabelId = ll.ID
    FROM SCore.LanguageLabels AS ll
    WHERE ll.Guid = @LanguageLabelGuid;

    EXEC SCore.UpsertDataObject
         @Guid = @ColumnGuid,
         @SchemeName = N'SUserInterface',
         @ObjectName = N'GridViewColumnDefinitions',
         @IsInsert = @IsInsert OUTPUT;

    IF (@IsInsert = 1)
    BEGIN
        INSERT INTO SUserInterface.GridViewColumnDefinitions
        (
            RowStatus,
            Guid,
            Name,
            ColumnOrder,
            GridViewDefinitionId,
            IsPrimaryKey,
            IsHidden,
            IsFiltered,
            IsCombo,
            IsLongitude,
            IsLatitude,
            LanguageLabelId
        )
        VALUES
        (
            1,
            @ColumnGuid,
            @Name,
            @ColumnOrder,
            @GridViewDefinitionId,
            @IsPrimaryKey,
            @IsHidden,
            @IsFiltered,
            @IsCombo,
            @IsLongitude,
            @IsLatitude,
            @LanguageLabelId
        );
    END
    ELSE
    BEGIN
        UPDATE SUserInterface.GridViewColumnDefinitions
        SET RowStatus = 1,
            Name = @Name,
            ColumnOrder = @ColumnOrder,
            GridViewDefinitionId = @GridViewDefinitionId,
            IsPrimaryKey = @IsPrimaryKey,
            IsHidden = @IsHidden,
            IsFiltered = @IsFiltered,
            IsCombo = @IsCombo,
            IsLongitude = @IsLongitude,
            IsLatitude = @IsLatitude,
            LanguageLabelId = @LanguageLabelId
        WHERE Guid = @ColumnGuid;
    END;
END;
GO
/* =========================================================================================
   10.2 Seed admin grid definitions and grid views for SAi entities
========================================================================================= */
DECLARE @Ll_KnowledgeGrid UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2300001';
DECLARE @Ll_WorkflowGrid UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2300002';
DECLARE @Ll_FeedbackGrid UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2300003';
DECLARE @Ll_ContentGapGrid UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2300004';
DECLARE @Gd_Knowledge UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2400001';
DECLARE @Gd_Workflows UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2400002';
DECLARE @Gd_Feedback UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2400003';
DECLARE @Gd_Gaps UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2400004';
DECLARE @Gv_Knowledge UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2500001';
DECLARE @Gv_Workflows UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2500002';
DECLARE @Gv_Feedback UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2500003';
DECLARE @Gv_Gaps UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2500004';
DECLARE @EtKnowledge UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000006';
DECLARE @EtWorkflow UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000012';
DECLARE @EtFeedback UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000015';
DECLARE @EtGap UNIQUEIDENTIFIER = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2000017';

EXEC SAi.Assistant_EnsureLanguageLabel @Name = N'Assistant Knowledge'
	,@Guid = @Ll_KnowledgeGrid OUTPUT;

EXEC SAi.Assistant_EnsureLanguageLabel @Name = N'Assistant Workflows'
	,@Guid = @Ll_WorkflowGrid OUTPUT;

EXEC SAi.Assistant_EnsureLanguageLabel @Name = N'Assistant Feedback'
	,@Guid = @Ll_FeedbackGrid OUTPUT;

EXEC SAi.Assistant_EnsureLanguageLabel @Name = N'Assistant Content Gaps'
	,@Guid = @Ll_ContentGapGrid OUTPUT;

EXEC SAi.Assistant_EnsureGridDefinition @Code = N'AIKNOWLEDGE'
	,@Name = N'Assistant Knowledge'
	,@PageUri = N'/assistant/admin/content'
	,@TabName = N'Knowledge'
	,@Guid = @Gd_Knowledge
	,@LanguageLabelGuid = @Ll_KnowledgeGrid

EXEC SAi.Assistant_EnsureGridDefinition @Code = N'AIWORKFLOWS'
	,@Name = N'Assistant Workflows'
	,@PageUri = N'/assistant/admin/workflows'
	,@TabName = N'Workflows'
	,@Guid = @Gd_Workflows
	,@LanguageLabelGuid = @Ll_WorkflowGrid

EXEC SAi.Assistant_EnsureGridDefinition @Code = N'AIFEEDBACK'
	,@Name = N'Assistant Feedback'
	,@PageUri = N'/assistant/admin/review'
	,@TabName = N'Feedback'
	,@Guid = @Gd_Feedback
	,@LanguageLabelGuid = @Ll_FeedbackGrid

EXEC SAi.Assistant_EnsureGridDefinition @Code = N'AICONTENTGAPS'
	,@Name = N'Assistant Content Gaps'
	,@PageUri = N'/assistant/admin/analytics'
	,@TabName = N'Content Gaps'
	,@Guid = @Gd_Gaps
	,@LanguageLabelGuid = @Ll_ContentGapGrid

EXEC SAi.Assistant_EnsureGridViewDefinition @Code = N'DEFAULT'
	,@GridDefinitionGuid = @Gd_Knowledge
	,@DetailPageUri = N'/assistant/admin/content'
	,@SqlQuery = N'SELECT ki.ID, ki.Guid, ki.Title, kc.Name AS Category, ki.ContentTypeCode, ki.SourceTypeCode, ki.IsAuthoritative, ki.IsPublished, ki.CreatedUtc, ki.UpdatedUtc FROM SAi.AssistantKnowledgeItems AS ki LEFT JOIN SAi.AssistantKnowledgeCategories AS kc ON (kc.ID = ki.KnowledgeCategoryId) WHERE (ki.RowStatus NOT IN (0, 254))'
	,@DefaultSortColumnName = N'UpdatedUtc'
	,@DisplayOrder = 10
	,@DisplayGroupName = N'Assistant'
	,@EntityTypeGuid = @EtKnowledge
	,@LanguageLabelGuid = @Ll_KnowledgeGrid
	,@Guid = @Gv_Knowledge OUTPUT
	,@ShowOnMobile = 1;

EXEC SAi.Assistant_EnsureGridViewDefinition @Code = N'DEFAULT'
	,@GridDefinitionGuid = @Gd_Workflows
	,@DetailPageUri = N'/assistant/admin/workflows'
	,@SqlQuery = N'SELECT wt.ID, wt.Guid, wt.Code, wt.Title, wt.AudienceCode, wt.OutputFormatCode, wt.IsPublished, wt.IsFeatured, wt.CreatedUtc, wt.UpdatedUtc FROM SAi.AssistantWorkflowTemplates AS wt WHERE (wt.RowStatus NOT IN (0, 254))'
	,@DefaultSortColumnName = N'UpdatedUtc'
	,@DisplayOrder = 10
	,@DisplayGroupName = N'Assistant'
	,@EntityTypeGuid = @EtWorkflow
	,@LanguageLabelGuid = @Ll_WorkflowGrid
	,@Guid = @Gv_Workflows OUTPUT
	,@ShowOnMobile = 1;

EXEC SAi.Assistant_EnsureGridViewDefinition @Code = N'DEFAULT'
	,@GridDefinitionGuid = @Gd_Feedback
	,@DetailPageUri = N'/assistant/admin/review'
	,@SqlQuery = N'SELECT f.ID, f.Guid, f.FeedbackCode, f.CreatedUtc, f.UserId, c.Title AS ConversationTitle, m.MessageRoleCode, LEFT(ISNULL(m.ContentPlainText, m.ContentMarkdown), 250) AS MessagePreview FROM SAi.AssistantFeedback AS f JOIN SAi.AssistantConversations AS c ON (c.ID = f.ConversationId) JOIN SAi.AssistantMessages AS m ON (m.ID = f.MessageId) WHERE (f.RowStatus NOT IN (0, 254))'
	,@DefaultSortColumnName = N'CreatedUtc'
	,@DisplayOrder = 10
	,@DisplayGroupName = N'Assistant'
	,@EntityTypeGuid = @EtFeedback
	,@LanguageLabelGuid = @Ll_FeedbackGrid
	,@Guid = @Gv_Feedback OUTPUT
	,@ShowOnMobile = 1;

EXEC SAi.Assistant_EnsureGridViewDefinition @Code = N'DEFAULT'
	,@GridDefinitionGuid = @Gd_Gaps
	,@DetailPageUri = N'/assistant/admin/analytics'
	,@SqlQuery = N'SELECT g.ID, g.Guid, g.Title, g.TopicCluster, g.OccurrenceCount, g.LastSeenUtc, g.StatusCode, ki.Title AS SuggestedKnowledgeItemTitle FROM SAi.AssistantContentGaps AS g LEFT JOIN SAi.AssistantKnowledgeItems AS ki ON (ki.ID = g.SuggestedKnowledgeItemId) WHERE (g.RowStatus NOT IN (0, 254))'
	,@DefaultSortColumnName = N'LastSeenUtc'
	,@DisplayOrder = 10
	,@DisplayGroupName = N'Assistant'
	,@EntityTypeGuid = @EtGap
	,@LanguageLabelGuid = @Ll_ContentGapGrid
	,@Guid = @Gv_Gaps OUTPUT
	,@ShowOnMobile = 1;

/* Knowledge columns */
EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Knowledge
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2600001'
	,@Name = N'Title'
	,@ColumnOrder = 10
	,@LanguageLabelName = N'AssistantKnowledge_Title';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Knowledge
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2600002'
	,@Name = N'Category'
	,@ColumnOrder = 20
	,@LanguageLabelName = N'AssistantKnowledge_Category';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Knowledge
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2600003'
	,@Name = N'ContentTypeCode'
	,@ColumnOrder = 30
	,@LanguageLabelName = N'AssistantKnowledge_ContentType';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Knowledge
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2600004'
	,@Name = N'SourceTypeCode'
	,@ColumnOrder = 40
	,@LanguageLabelName = N'AssistantKnowledge_SourceType';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Knowledge
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2600005'
	,@Name = N'IsAuthoritative'
	,@ColumnOrder = 50
	,@LanguageLabelName = N'AssistantKnowledge_IsAuthoritative';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Knowledge
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2600006'
	,@Name = N'IsPublished'
	,@ColumnOrder = 60
	,@LanguageLabelName = N'AssistantKnowledge_IsPublished';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Knowledge
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2600007'
	,@Name = N'CreatedUtc'
	,@ColumnOrder = 70
	,@LanguageLabelName = N'AssistantKnowledge_CreatedUtc';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Knowledge
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2600008'
	,@Name = N'UpdatedUtc'
	,@ColumnOrder = 80
	,@LanguageLabelName = N'AssistantKnowledge_UpdatedUtc';

/* Workflow columns */
EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Workflows
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2610001'
	,@Name = N'Code'
	,@ColumnOrder = 10
	,@LanguageLabelName = N'AssistantWorkflow_Code';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Workflows
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2610002'
	,@Name = N'Title'
	,@ColumnOrder = 20
	,@LanguageLabelName = N'AssistantWorkflow_Title';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Workflows
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2610003'
	,@Name = N'AudienceCode'
	,@ColumnOrder = 30
	,@LanguageLabelName = N'AssistantWorkflow_Audience';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Workflows
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2610004'
	,@Name = N'OutputFormatCode'
	,@ColumnOrder = 40
	,@LanguageLabelName = N'AssistantWorkflow_OutputFormat';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Workflows
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2610005'
	,@Name = N'IsPublished'
	,@ColumnOrder = 50
	,@LanguageLabelName = N'AssistantWorkflow_IsPublished';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Workflows
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2610006'
	,@Name = N'IsFeatured'
	,@ColumnOrder = 60
	,@LanguageLabelName = N'AssistantWorkflow_IsFeatured';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Workflows
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2610007'
	,@Name = N'CreatedUtc'
	,@ColumnOrder = 70
	,@LanguageLabelName = N'AssistantWorkflow_CreatedUtc';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Workflows
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2610008'
	,@Name = N'UpdatedUtc'
	,@ColumnOrder = 80
	,@LanguageLabelName = N'AssistantWorkflow_UpdatedUtc';

/* Feedback columns */
EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Feedback
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2620001'
	,@Name = N'FeedbackCode'
	,@ColumnOrder = 10
	,@LanguageLabelName = N'AssistantFeedback_FeedbackCode';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Feedback
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2620002'
	,@Name = N'CreatedUtc'
	,@ColumnOrder = 20
	,@LanguageLabelName = N'AssistantFeedback_CreatedUtc';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Feedback
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2620003'
	,@Name = N'UserId'
	,@ColumnOrder = 30
	,@LanguageLabelName = N'AssistantFeedback_UserId';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Feedback
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2620004'
	,@Name = N'ConversationTitle'
	,@ColumnOrder = 40
	,@LanguageLabelName = N'AssistantFeedback_ConversationTitle';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Feedback
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2620005'
	,@Name = N'MessageRoleCode'
	,@ColumnOrder = 50
	,@LanguageLabelName = N'AssistantFeedback_MessageRole';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Feedback
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2620006'
	,@Name = N'MessagePreview'
	,@ColumnOrder = 60
	,@LanguageLabelName = N'AssistantFeedback_MessagePreview';

/* Content gap columns */
EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Gaps
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2630001'
	,@Name = N'Title'
	,@ColumnOrder = 10
	,@LanguageLabelName = N'AssistantGap_Title';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Gaps
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2630002'
	,@Name = N'TopicCluster'
	,@ColumnOrder = 20
	,@LanguageLabelName = N'AssistantGap_TopicCluster';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Gaps
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2630003'
	,@Name = N'OccurrenceCount'
	,@ColumnOrder = 30
	,@LanguageLabelName = N'AssistantGap_OccurrenceCount';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Gaps
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2630004'
	,@Name = N'LastSeenUtc'
	,@ColumnOrder = 40
	,@LanguageLabelName = N'AssistantGap_LastSeenUtc';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Gaps
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2630005'
	,@Name = N'StatusCode'
	,@ColumnOrder = 50
	,@LanguageLabelName = N'AssistantGap_StatusCode';

EXEC SAi.Assistant_EnsureGridColumn @GridViewGuid = @Gv_Gaps
	,@ColumnGuid = '9C87EFA0-0A5C-4A49-9AF5-9B5AF2630006'
	,@Name = N'SuggestedKnowledgeItemTitle'
	,@ColumnOrder = 60
	,@LanguageLabelName = N'AssistantGap_SuggestedKnowledgeItem';

GO
IF OBJECT_ID(N'SAi.tvf_AssistantBookmarkList', N'IF') IS NULL
BEGIN
    EXEC(N'
    CREATE FUNCTION SAi.tvf_AssistantBookmarkList
    (
        @UserId INT
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT
            b.ID,
            b.Guid,
            CONVERT(NVARCHAR(36), c.Guid) AS ConversationGuid,
            CONVERT(NVARCHAR(36), m.Guid) AS MessageGuid,
            b.UserId,
            b.Title,
            b.Notes,
            b.TagsJson,
            b.CreatedUtc
        FROM SAi.AssistantBookmarks b
        JOIN SAi.AssistantConversations c ON c.ID = b.ConversationId
        JOIN SAi.AssistantMessages m ON m.ID = b.MessageId
        WHERE b.UserId = @UserId
          AND b.RowStatus NOT IN (0, 254)
    );
    ');
END;
GO

IF OBJECT_ID(N'SAi.tvf_AssistantWorkflowTemplateList', N'IF') IS NULL
BEGIN
    EXEC(N'
    CREATE FUNCTION SAi.tvf_AssistantWorkflowTemplateList
    (
        @PublishedOnly BIT,
        @FeaturedOnly BIT,
        @AudienceCode NVARCHAR(30)
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT
            wt.ID,
            wt.Guid,
            wt.Code,
            wt.Title,
            wt.Summary,
            wt.AudienceCode,
            wt.TemplatePrompt,
            wt.ClarificationSchemaJson,
            wt.OutputFormatCode,
            wt.IsPublished,
            wt.IsFeatured,
            wt.CreatedByUserId,
            wt.CreatedUtc,
            wt.UpdatedUtc
        FROM SAi.AssistantWorkflowTemplates wt
        WHERE wt.RowStatus NOT IN (0, 254)
          AND (@PublishedOnly = 0 OR wt.IsPublished = 1)
          AND (@FeaturedOnly = 0 OR wt.IsFeatured = 1)
          AND (ISNULL(@AudienceCode, N'''') = N'''' OR wt.AudienceCode = @AudienceCode)
    );
    ');
END;
GO

IF OBJECT_ID(N'SAi.tvf_AssistantUploadListByUser', N'IF') IS NULL
BEGIN
    EXEC(N'
    CREATE FUNCTION SAi.tvf_AssistantUploadListByUser
    (
        @UserId INT
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT
            u.ID,
            u.Guid,
            CONVERT(NVARCHAR(36), c.Guid) AS ConversationGuid,
            CONVERT(NVARCHAR(36), ki.Guid) AS KnowledgeItemGuid,
            u.UserId,
            u.StorageUrl,
            u.FileName,
            u.ContentType,
            u.FileSizeBytes,
            u.UploadPurposeCode,
            u.ProcessingStatusCode,
            u.VisionSummary,
            u.CreatedUtc
        FROM SAi.AssistantUploads u
        LEFT JOIN SAi.AssistantConversations c ON c.ID = u.ConversationId
        LEFT JOIN SAi.AssistantKnowledgeItems ki ON ki.ID = u.KnowledgeItemId
        WHERE u.UserId = @UserId
          AND u.RowStatus NOT IN (0, 254)
    );
    ');
END;
GO

IF OBJECT_ID(N'SAi.tvf_AssistantUploadListByGuids', N'IF') IS NULL
BEGIN
    EXEC(N'
    CREATE FUNCTION SAi.tvf_AssistantUploadListByGuids
    (
        @UploadGuids SCore.GuidUniqueList READONLY
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT
            u.ID,
            u.Guid,
            CONVERT(NVARCHAR(36), c.Guid) AS ConversationGuid,
            CONVERT(NVARCHAR(36), ki.Guid) AS KnowledgeItemGuid,
            u.UserId,
            u.StorageUrl,
            u.FileName,
            u.ContentType,
            u.FileSizeBytes,
            u.UploadPurposeCode,
            u.ProcessingStatusCode,
            u.VisionSummary,
            u.CreatedUtc
        FROM SAi.AssistantUploads u
        JOIN @UploadGuids g ON g.GuidValue = u.Guid
        LEFT JOIN SAi.AssistantConversations c ON c.ID = u.ConversationId
        LEFT JOIN SAi.AssistantKnowledgeItems ki ON ki.ID = u.KnowledgeItemId
        WHERE u.RowStatus NOT IN (0, 254)
    );
    ');
END;
GO

IF OBJECT_ID(N'SAi.tvf_AssistantFeedbackList', N'IF') IS NULL
BEGIN
    EXEC(N'
    CREATE FUNCTION SAi.tvf_AssistantFeedbackList
    (
        @IncludeHelpful BIT,
        @IncludeUnhelpful BIT
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT
            f.ID,
            f.Guid,
            f.UserId,
            CONVERT(NVARCHAR(36), c.Guid) AS ConversationGuid,
            CONVERT(NVARCHAR(36), m.Guid) AS MessageGuid,
            f.FeedbackCode,
            f.Comment,
            f.CreatedUtc,
            c.Title AS ConversationTitle,
            LEFT(COALESCE(NULLIF(m.ContentPlainText, N''''), m.ContentMarkdown), 300) AS MessagePreview,
            m.AnswerTypeCode,
            m.ConfidenceScore
        FROM SAi.AssistantFeedback f
        JOIN SAi.AssistantConversations c ON c.ID = f.ConversationId
        JOIN SAi.AssistantMessages m ON m.ID = f.MessageId
        WHERE f.RowStatus NOT IN (0, 254)
          AND
          (
              (@IncludeHelpful = 1 AND f.FeedbackCode = N''HELPFUL'')
              OR (@IncludeUnhelpful = 1 AND f.FeedbackCode = N''UNHELPFUL'')
          )
    );
    ');
END;
GO

IF OBJECT_ID(N'SAi.tvf_AssistantFailedAnswers', N'IF') IS NULL
BEGIN
    EXEC(N'
    CREATE FUNCTION SAi.tvf_AssistantFailedAnswers
    (
        @MaxConfidenceScore DECIMAL(5,4),
        @Take INT
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT TOP (CASE WHEN @Take < 1 THEN 25 ELSE @Take END)
            CONVERT(NVARCHAR(36), c.Guid) AS ConversationGuid,
            CONVERT(NVARCHAR(36), m.Guid) AS MessageGuid,
            c.Title AS ConversationTitle,
            LEFT(COALESCE(NULLIF(m.ContentPlainText, N''''), m.ContentMarkdown), 300) AS MessagePreview,
            ISNULL(m.ConfidenceScore, 0) AS ConfidenceScore,
            m.CreatedUtc
        FROM SAi.AssistantMessages m
        JOIN SAi.AssistantConversations c ON c.ID = m.ConversationId
        WHERE m.RowStatus NOT IN (0, 254)
          AND c.RowStatus NOT IN (0, 254)
          AND m.MessageRoleCode = N''ASSISTANT''
          AND ISNULL(m.ConfidenceScore, 0) <= ISNULL(@MaxConfidenceScore, 0.50)
        ORDER BY m.CreatedUtc DESC
    );
    ');
END;
GO