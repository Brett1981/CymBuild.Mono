using Xunit;

namespace CymBuild.Architecture.Tests;

public sealed class Cyb524GridFollowUpSourceContractTests
{
    [Fact]
    public void FilteredDynamicGridViewV2_WiresSharedEdgeHoverAutoScroll()
    {
        var razor = ReadPwaSharedFile("FilteredDynamicGridViewV2.razor");
        var codeBehind = ReadPwaSharedFile("FilteredDynamicGridViewV2.razor.cs");
        var authorisation = ReadPwaSharedFile("FilteredDynamicGridViewV2.Authorisation.cs");

        Assert.Contains("id=\"@GridWrapperDomId\" class=\"native-grid-scroll\"", razor, StringComparison.Ordinal);
        Assert.Contains("cymbuildGridEdgeAutoScroll.attach", codeBehind, StringComparison.Ordinal);
        Assert.Contains("cymbuildGridEdgeAutoScroll.detach", authorisation, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("DynamicGridView.razor.css")]
    [InlineData("DynamicBatchGridView.razor.css")]
    [InlineData("FilteredDynamicGridViewV2.razor.css")]
    [InlineData("DynamicTreeListGridView.razor.css")]
    public void GridRenderer_ProvidesBoundedVerticalScrollViewport(string fileName)
    {
        var css = ReadPwaSharedFile(fileName);

        Assert.Contains("max-height: 68vh", css, StringComparison.Ordinal);
        Assert.True(
            css.Contains("overflow: auto", StringComparison.Ordinal)
            || css.Contains("overflow-y: auto", StringComparison.Ordinal),
            $"{fileName} must provide vertical scrolling inside its bounded viewport.");
    }

    [Fact]
    public void TreeGrid_KeepsHeaderVisibleWithinItsScrollViewport()
    {
        var css = ReadPwaSharedFile("DynamicTreeListGridView.razor.css");

        Assert.Contains(".cb-tree-grid-table thead", css, StringComparison.Ordinal);
        Assert.Contains("position: sticky", css, StringComparison.Ordinal);
        Assert.Contains("top: 0", css, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("DynamicGridView.razor.css", ".dynamic-grid-view-v2-grid-table thead")]
    [InlineData("FilteredDynamicGridView.razor.css", ".cb-filtered-grid-table thead")]
    [InlineData("FilteredDynamicGridViewV2.razor.css", ".filtered-dynamic-grid-view-v2-shell .native-grid-table thead")]
    public void StandardGridRenderers_KeepHeaderGroupInsideScrollViewport(
        string fileName,
        string headerSelector)
    {
        var css = ReadPwaSharedFile(fileName);

        Assert.Contains(headerSelector, css, StringComparison.Ordinal);
        Assert.Contains("position: sticky", css, StringComparison.Ordinal);
        Assert.Contains("top: 0", css, StringComparison.Ordinal);
    }

    [Fact]
    public void DynamicGridView_ScopedStylesheetRemainsInBuildInputs()
    {
        var projectFile = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "Concursus.PWA.csproj"));

        Assert.DoesNotContain(
            "<None Remove=\"Shared\\DynamicGridView.razor.css\" />",
            projectFile,
            StringComparison.Ordinal);
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
