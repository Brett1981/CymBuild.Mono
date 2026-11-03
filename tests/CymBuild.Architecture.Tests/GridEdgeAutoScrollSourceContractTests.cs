using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-524: Grid scrolling/navigation enhancement.
//
// Edge-hover auto horizontal-scroll and frozen (position: sticky) column
// headers are shared across every flat grid component in CymBuild, wired
// through one interop module (wwwroot/grid-edge-auto-scroll.js) rather than
// duplicated per component.
//
// Evidence for which SUserInterface.GridViewDefinitions route through which
// component (Database/CymBuild_DB/Scripts/Upgrade Scripts/MetaData Tables For
// CymBuild.sql, cross-referenced against the routing chain in
// apps/Concursus.PWA/Shared/DynamicGrid.razor):
//   ALLJOBS              GridViewTypeId=1  -> DynamicGridView          (Jobs)
//   SAGEEXPORT           GridViewTypeId=1  -> DynamicGridView          (Finance/Sage)
//   ALLTRANSACTIONS      GridViewTypeId=1, Code-special-cased          -> FilteredDynamicGridView ("Transactions" tab)
//   BATCHEDTRANSACTIONS  Code-special-cased                            -> DynamicBatchGridView ("Batched" tab)
//   JOBPAYMENTSTAGEBATCH GridViewTypeId=2 (falls to default branch)    -> DynamicBatchGridView
//   INVOICEREQUESTS      GridViewTypeId=2 (falls to default branch)    -> DynamicBatchGridView
//   ALLSAGESUBMON        Code-special-cased                            -> DynamicBatchGridView
//   FILTEREDQUOTES       GridCode-special-cased                        -> FilteredDynamicGridView
// MYINVOICING and TEAMSINVOICING are GridViewTypeId=5 (DynamicTreeListGridView)
// and are out of scope for this change: a tree grid is a different navigation
// shape and was not covered by this ticket.
public sealed class GridEdgeAutoScrollSourceContractTests
{
    [Fact]
    public void SharedInteropModule_DefinesAttachAndDetachAndIsLoadedByIndexHtml()
    {
        var script = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "wwwroot",
                "grid-edge-auto-scroll.js"));

        Assert.Contains("window.cymbuildGridEdgeAutoScroll.attach = function (elementId)", script, StringComparison.Ordinal);
        Assert.Contains("window.cymbuildGridEdgeAutoScroll.detach = function (elementId)", script, StringComparison.Ordinal);
        Assert.Contains("edgeZonePx", script, StringComparison.Ordinal);
        Assert.Contains("cancelAnimationFrame", script, StringComparison.Ordinal);

        var index = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "wwwroot",
                "index.html"));

        Assert.Contains("<script src=\"grid-edge-auto-scroll.js\"></script>", index, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("DynamicGridView", "id=\"@GridWrapperDomId\" class=\"cb-v2-table-wrap dynamic-grid-view-v2-grid-wrapper\"")]
    [InlineData("FilteredDynamicGridView", "id=\"@GridWrapperDomId\" class=\"cb-filtered-grid-scroll\"")]
    [InlineData("DynamicBatchGridView", "id=\"@GridWrapperDomId\" class=\"cb-v2-table-wrap dynamic-batch-grid-v2-grid-wrapper\"")]
    public void GridComponent_WiresSharedEdgeAutoScrollInterop(string componentName, string wrapperMarkup)
    {
        var razorCs = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "Shared",
                $"{componentName}.razor.cs"));

        Assert.Contains("cymbuildGridEdgeAutoScroll.attach", razorCs, StringComparison.Ordinal);
        Assert.Contains("cymbuildGridEdgeAutoScroll.detach", razorCs, StringComparison.Ordinal);
        Assert.Contains("GridWrapperDomId", razorCs, StringComparison.Ordinal);
        Assert.Contains("IDisposable", razorCs, StringComparison.Ordinal);

        var attachIndex = razorCs.IndexOf("OnAfterRenderAsync", StringComparison.Ordinal);
        var disposeIndex = razorCs.IndexOf("public void Dispose()", StringComparison.Ordinal);

        Assert.True(attachIndex >= 0, $"{componentName} must attach edge auto-scroll from OnAfterRenderAsync.");
        Assert.True(disposeIndex > attachIndex, $"{componentName}.Dispose() must exist and run after attach so interop listeners are cleaned up.");

        var razor = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "Shared",
                $"{componentName}.razor"));

        Assert.Contains(wrapperMarkup, razor, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("DynamicGridView", ".dynamic-grid-view-v2-grid-table thead th {")]
    [InlineData("FilteredDynamicGridView", ".cb-filtered-grid-table th {")]
    [InlineData("DynamicBatchGridView", ".dynamic-batch-grid-v2-grid-table thead th {")]
    public void GridComponent_KeepsColumnHeadersFrozenDuringVerticalScroll(string componentName, string headerRuleSelector)
    {
        var css = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "Shared",
                $"{componentName}.razor.css"));

        var headerRuleIndex = css.IndexOf(headerRuleSelector, StringComparison.Ordinal);
        Assert.True(headerRuleIndex >= 0, $"{componentName} must keep its sticky header rule ('{headerRuleSelector}').");

        var headerRule = css.Substring(headerRuleIndex, 200);
        Assert.Contains("position: sticky", headerRule, StringComparison.Ordinal);
        Assert.Contains("top: 0", headerRule, StringComparison.Ordinal);
    }
}
