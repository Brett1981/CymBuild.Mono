using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-320: SSop.tvf_QuotesValidate locks the Quote's Job Type while it has quote items. Adding or
/// removing an item happens in the Quote Items grid, so the parent Quote must be re-read (which
/// re-runs validation) when that grid's detail window closes - otherwise Job Type keeps its old
/// read-only state until a page reload. DynamicGridView only re-reads the parent when the grid
/// is given a ResyncDataObject callback.
/// </summary>
public sealed class Cyb320QuoteItemsResyncSourceContractTests
{
    [Fact]
    public void QuoteDetail_QuoteItemsGrid_ResyncsTheParentQuote()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Pages", "QuoteDetail.razor"));

        var gridLine = source
            .Replace("\r\n", "\n")
            .Split('\n')
            .Single(line => line.Contains("GridCode=\"QUOTEITEMS\"", StringComparison.Ordinal));

        Assert.Contains("ResyncDataObject=\"@editPage.ReSyncDataObject\"", gridLine, StringComparison.Ordinal);
    }

    [Fact]
    public void DynamicGridView_CloseWindow_ResyncsTheParentForNewAndExistingRows()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Shared", "DynamicGridView.razor.cs"))
            .Replace("\r\n", "\n");

        var start = source.IndexOf("protected async Task CloseWindow()", StringComparison.Ordinal);
        var end = source.IndexOf("protected async Task GridUpdated()", start, StringComparison.Ordinal);
        Assert.True(start >= 0 && end > start, "DynamicGridView.CloseWindow() was not found.");

        var closeWindow = source[start..end];

        // Once for a new row (!ComingFromModal), once for an existing row opened by double-click.
        var resyncCalls = closeWindow.Split("if (ResyncDataObject.HasDelegate) await ResyncDataObject.InvokeAsync();").Length - 1;
        Assert.Equal(2, resyncCalls);
    }

    [Fact]
    public void ButtonMenu_Delete_ClosesTheHostWindowInsteadOfNavigatingToTheSamePage()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Shared", "ButtonMenu.razor.cs"))
            .Replace("\r\n", "\n");

        var start = source.IndexOf("else if (item.Text == \"Delete\")", StringComparison.Ordinal);
        Assert.True(start >= 0, "ButtonMenu Delete handler was not found.");

        var closeIndex = source.IndexOf("else if (OnClose.HasDelegate)\n                    {\n                        await OnClose.InvokeAsync();", start, StringComparison.Ordinal);
        var navigateIndex = source.IndexOf("_ = NavigateToUrlAsync(ReturnUrl ?? \"\", item.OpenInNewTab);", start, StringComparison.Ordinal);

        Assert.True(closeIndex > start, "Delete must close a windowed host via OnClose.");
        Assert.True(closeIndex < navigateIndex, "OnClose must be tried before falling back to navigation.");
    }
}
