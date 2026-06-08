SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantWorkflowTemplateUpsert]')
GO

/* =========================================================================================
   9.6 Workflow template upsert
========================================================================================= */
CREATE PROCEDURE [SAi].[AssistantWorkflowTemplateUpsert] (
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