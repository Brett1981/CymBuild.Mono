SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[Assistant_EnsureLanguageLabel]')
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
CREATE PROCEDURE [SAi].[Assistant_EnsureLanguageLabel] (
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