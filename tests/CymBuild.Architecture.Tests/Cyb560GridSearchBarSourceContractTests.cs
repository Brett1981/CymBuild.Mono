using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-560: GridViewDefinitions.ShowSearchBar / IsSearchDefaultCollapsed.
// DynamicGridView lives in the PWA (no bUnit host), so its render states are pinned as source
// contracts, matching the other DynamicGridView tests in this project. The SQL chain is pinned
// here because a column dropped from any one link silently reads as false (search bar hidden).
public sealed class Cyb560GridSearchBarSourceContractTests
{
    private static readonly string[] NewColumns = ["ShowSearchBar", "IsSearchDefaultCollapsed"];

    [Fact]
    public void GridViewDefinitionsTable_DefaultsSearchBarShownAndExpanded()
    {
        var table = ReadSchemaFile("Tables", "SUserInterface.GridViewDefinitions.sql");

        // Existing rows must keep today's behaviour: search bar shown, not collapsed.
        Assert.Contains("[ShowSearchBar] [bit] NOT NULL CONSTRAINT [DF_GridViewDefinitions_ShowSearchBar] DEFAULT (1)", table, StringComparison.Ordinal);
        Assert.Contains("[IsSearchDefaultCollapsed] [bit] NOT NULL CONSTRAINT [DF_GridViewDefinitions_IsSearchDefaultCollapsed] DEFAULT (0)", table, StringComparison.Ordinal);
    }

    [Fact]
    public void GridViewDefinitionsTvf_ExposesBothColumns()
    {
        var tvf = ReadSchemaFile("Programmability", "Functions", "SUserInterface.tvf_GridViewDefinitions.sql");

        foreach (var column in NewColumns)
        {
            Assert.Contains($"gvd.[{column}] AS [{column}]", tvf, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void GridViewDefinitionUpsert_AcceptsInsertsAndUpdatesBothColumns()
    {
        var upsert = ReadSchemaFile("Programmability", "Procedures", "SUserInterface.GridViewDefinitionUpsert.sql");

        foreach (var column in NewColumns)
        {
            Assert.Contains($"@{column}", upsert, StringComparison.Ordinal);
            Assert.Contains($"{column} = @{column}", upsert, StringComparison.Ordinal);
            // Parameter declaration + INSERT VALUES + UPDATE SET.
            Assert.Equal(3, CountOccurrences(upsert, $"@{column}"));
        }
    }

    [Fact]
    public void MetadataApplyRun_PromotesBothColumnsFromStagedPayload()
    {
        var apply = ReadSchemaFile("Programmability", "Procedures", "SMigration.MetadataApply_Run.sql");

        foreach (var column in NewColumns)
        {
            Assert.Contains($"TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.{column}'))", apply, StringComparison.Ordinal);
            Assert.Contains($"@{column} = @GVD_{column}", apply, StringComparison.Ordinal);
            // Per-column source/target selection must cover the new columns like every other scalar.
            Assert.Contains($"WHERE [value] = N'{column}') SET @GVD_{column} = @GVD_Target_{column};", apply, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void ProtoEfReaderAndConverters_CarryBothColumns()
    {
        var proto = File.ReadAllText(RepositoryLayout.PathFromRoot("services", "Concursus.API", "Protos", "core.proto"));
        Assert.Contains("bool ShowSearchBar = 53;", proto, StringComparison.Ordinal);
        Assert.Contains("bool IsSearchDefaultCollapsed = 54;", proto, StringComparison.Ordinal);

        var reader = File.ReadAllText(RepositoryLayout.PathFromRoot("libs", "Concursus.EF", "UserInterface.cs"));
        var converters = File.ReadAllText(RepositoryLayout.PathFromRoot("services", "Concursus.API", "Classes", "Converters.cs"));

        foreach (var column in NewColumns)
        {
            Assert.Contains($"{column} = reader.GetBoolean(reader.GetOrdinal(\"{column}\"))", reader, StringComparison.Ordinal);
            Assert.Equal(2, CountOccurrences(converters, $"{column} = request.{column}"));
        }
    }

    [Fact]
    public void SeedMetadata_RegistersPropertiesLabelsAndTranslationsByStableGuid()
    {
        var seed = File.ReadAllText(RepositoryLayout.PathFromRoot("Database", "CymBuild_DB", "Scripts", "Upgrade Scripts", "MetaData Tables For CymBuild.sql"));

        // EntityProperties, LanguageLabels, LanguageLabelTranslations
        Assert.Contains("N'9f823354-d0cd-4bef-bd14-3169a0695466', N'ShowSearchBar'", seed, StringComparison.Ordinal);
        Assert.Contains("N'9c45ee8d-07ba-4cf4-bbd0-6d92f529042d', N'IsSearchDefaultCollapsed'", seed, StringComparison.Ordinal);
        Assert.Contains("N'3e6e1209-584a-4639-b710-aa4e1575ae97', N'[SUserInterface].[GridViewDefinitions].[ShowSearchBar]'", seed, StringComparison.Ordinal);
        Assert.Contains("N'aea5a6d1-7b36-4cbe-b812-680e23fbc126', N'[SUserInterface].[GridViewDefinitions].[IsSearchDefaultCollapsed]'", seed, StringComparison.Ordinal);
        Assert.Contains("N'f550373d-359a-43f8-b765-0e3f3269d215', N'Show Search Bar'", seed, StringComparison.Ordinal);
        Assert.Contains("N'437a37e7-3ead-4a7e-a8ce-e3012a1b4c3d', N'Search Collapsed By Default'", seed, StringComparison.Ordinal);
    }

    [Fact]
    public void DynamicGridView_SearchToolbarCardOnlyRendersWhenSearchBarShownAndExpanded()
    {
        var razor = ReadPwaSharedFile("DynamicGridView.razor");
        var codeBehind = ReadPwaSharedFile("DynamicGridView.razor.cs");

        Assert.Contains("private bool IsSearchToolbarVisible => ViewDefinition.ShowSearchBar && !_isSearchBarCollapsed;", codeBehind, StringComparison.Ordinal);

        // ShowSearchBar = 0 or collapsed: the whole toolbar card goes (a drawdown error still gets a card).
        var cardGate = razor.IndexOf("@if (IsSearchToolbarVisible || !string.IsNullOrWhiteSpace(DrawdownInlineError))", StringComparison.Ordinal);
        var toolbarGate = razor.IndexOf("@if (IsSearchToolbarVisible)", StringComparison.Ordinal);
        var toolbar = razor.IndexOf("<div class=\"cb-v2-toolbar dynamic-grid-view-v2-toolbar\">", StringComparison.Ordinal);
        Assert.True(cardGate >= 0, "Toolbar card must be gated on IsSearchToolbarVisible.");
        Assert.True(cardGate < toolbarGate && toolbarGate < toolbar, "Toolbar markup must sit inside the IsSearchToolbarVisible gates.");

        // Filters is part of the search controls: its toggle sits in the gated toolbar, and its panel is gated too.
        var toolbarRight = razor.IndexOf("dynamic-grid-view-v2-toolbar-right", toolbar, StringComparison.Ordinal);
        var filterToggle = razor.IndexOf("dynamic-grid-view-v2-filter-toggle", StringComparison.Ordinal);
        Assert.True(toolbar < filterToggle && filterToggle < toolbarRight, "Filters toggle must render inside the gated search toolbar.");
        Assert.Contains("@if (_isFilterPanelOpen && IsSearchToolbarVisible)", razor, StringComparison.Ordinal);
    }

    [Fact]
    public void DynamicGridView_CollapsedModeUsesCompactHeaderToggleWithActiveCriteriaBadge()
    {
        var razor = ReadPwaSharedFile("DynamicGridView.razor");
        var codeBehind = ReadPwaSharedFile("DynamicGridView.razor.cs");

        var headerRight = razor.IndexOf("dynamic-grid-view-v2-header-right", StringComparison.Ordinal);
        var toggleGate = razor.IndexOf("@if (ViewDefinition.ShowSearchBar && ViewDefinition.IsSearchDefaultCollapsed)", StringComparison.Ordinal);
        var newButton = razor.IndexOf("id=\"newBtn\"", StringComparison.Ordinal);
        Assert.True(headerRight >= 0 && headerRight < toggleGate && toggleGate < newButton,
            "Collapsed Search toggle must live in the header actions (before New), not in its own toolbar row.");

        var toggleBlock = razor.Substring(toggleGate, newButton - toggleGate);
        Assert.Contains("@onclick=\"ToggleSearchBar\"", toggleBlock, StringComparison.Ordinal);
        Assert.Contains("aria-expanded=\"@(!_isSearchBarCollapsed)\"", toggleBlock, StringComparison.Ordinal);
        Assert.Contains("@ActiveSearchCriteriaCount", toggleBlock, StringComparison.Ordinal);

        // Only one toggle: the old in-toolbar toggle must not come back.
        Assert.Equal(1, CountOccurrences(razor, "dynamic-grid-view-v2-search-toggle"));

        Assert.Contains("private int ActiveSearchCriteriaCount => (string.IsNullOrWhiteSpace(_searchText) ? 0 : 1) + _filtersByColumn.Count;", codeBehind, StringComparison.Ordinal);
        Assert.Contains("_isSearchBarCollapsed = ViewDefinition.IsSearchDefaultCollapsed;", codeBehind, StringComparison.Ordinal);
    }

    [Fact]
    public void DynamicGridView_ClearsRestoredSearchAndFiltersWhenSearchBarHidden()
    {
        var codeBehind = ReadPwaSharedFile("DynamicGridView.razor.cs");

        var restore = codeBehind.IndexOf("await RestoreNativeGridStateAsync();", StringComparison.Ordinal);
        var hiddenGuard = codeBehind.IndexOf("if (!ViewDefinition.ShowSearchBar)", restore, StringComparison.Ordinal);
        var defaultSort = codeBehind.IndexOf("ApplyDefaultSortIfNeeded();", restore, StringComparison.Ordinal);
        Assert.True(restore >= 0 && restore < hiddenGuard && hiddenGuard < defaultSort,
            "Restored grid state must be cleared right after it is restored when the search bar is hidden.");

        var guardBlock = codeBehind.Substring(hiddenGuard, defaultSort - hiddenGuard);
        Assert.Contains("_searchText = string.Empty;", guardBlock, StringComparison.Ordinal);
        Assert.Contains("_filtersByColumn.Clear();", guardBlock, StringComparison.Ordinal);
    }

    private static int CountOccurrences(string text, string value)
    {
        var count = 0;
        var index = 0;
        while ((index = text.IndexOf(value, index, StringComparison.Ordinal)) >= 0)
        {
            count++;
            index += value.Length;
        }

        return count;
    }

    private static string ReadSchemaFile(params string[] segments)
    {
        return File.ReadAllText(RepositoryLayout.PathFromRoot(["Database", "CymBuild_DB", "Schema", .. segments]));
    }

    private static string ReadPwaSharedFile(string fileName)
    {
        return File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "Shared",
                fileName));
    }
}
