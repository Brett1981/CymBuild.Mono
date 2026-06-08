SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[Assistant_EnsureGridDefinition]')
GO

CREATE PROCEDURE [SAi].[Assistant_EnsureGridDefinition] (
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