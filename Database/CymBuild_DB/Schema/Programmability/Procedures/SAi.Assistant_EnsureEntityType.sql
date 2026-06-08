SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[Assistant_EnsureEntityType]')
GO

/* =========================================================================================
       2. Helper procedure for assistant EntityType creation
          - Creates LanguageLabel if needed
          - Creates EntityType as a proper DataObject-backed entity via SCore.EntityTypeUpsert
    ========================================================================================= */
CREATE PROCEDURE [SAi].[Assistant_EnsureEntityType] (
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