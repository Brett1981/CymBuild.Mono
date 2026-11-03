using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-579: the "select all" header checkbox on the bulk-update grids only selected the visible
/// page, so a bulk update silently skipped every other page. Both grids load all rows and page them
/// client-side; the header checkbox must now act on every row matching the current filters, and the
/// selection passed to the update must be limited to those filtered rows. The grids live in the PWA
/// (no bUnit host), so this is pinned as a source contract. Progress/failure handling is covered by
/// BulkOperationRunnerTests; here we pin that the update loops actually go through it.
/// </summary>
public sealed class Cyb579BulkUpdateSelectAllSourceContractTests
{
    [Fact]
    public void ActivityBulkUpdateGrid_HeaderCheckboxSelectsEveryFilteredRow()
    {
        var source = ReadPwa("Shared", "ActivityBulkUpdateGrid.razor");

        Assert.Contains("checked=\"@AreAllFilteredRowsSelected\"", source, StringComparison.Ordinal);
        Assert.Contains("@onchange=\"ToggleSelectAllFilteredRows\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ToggleSelectAllCurrentPage", source, StringComparison.Ordinal);
        Assert.DoesNotContain("IsCurrentPageFullySelected", source, StringComparison.Ordinal);

        Assert.Contains("foreach (var rowKey in FilteredRowKeys.ToList())", source, StringComparison.Ordinal);
        Assert.Contains("_filteredRows\n            .Select(row => GetRowKey(", source, StringComparison.Ordinal);
    }

    [Fact]
    public void ActivityBulkUpdateGrid_SendsOnlySelectedFilteredRowsToTheUpdate()
    {
        var source = ReadPwa("Shared", "ActivityBulkUpdateGrid.razor");

        Assert.Contains("private List<ExpandoObject> GetSelectedRows()\n    {\n        return _filteredRows", source, StringComparison.Ordinal);
        Assert.Contains("{ \"SelectedItems\", selectedRows }", source, StringComparison.Ordinal);
    }

    [Fact]
    public void DynamicBatchGridView_HeaderCheckboxSelectsEveryFilteredRow()
    {
        var markup = ReadPwa("Shared", "DynamicBatchGridView.razor");
        var code = ReadPwa("Shared", "DynamicBatchGridView.razor.cs");

        Assert.Contains("checked=\"@AreAllFilteredRowsSelected\"", markup, StringComparison.Ordinal);
        Assert.Contains("@onchange=\"ToggleSelectAllFilteredRows\"", markup, StringComparison.Ordinal);
        Assert.Contains("<span class=\"cb-v2-pill-value\">@SelectedItems.Count</span>", markup, StringComparison.Ordinal);

        Assert.Contains("foreach (var guid in FilteredRowGuids.ToList())", code, StringComparison.Ordinal);
        Assert.Contains("FilteredRows\n            .Select(r => GetRowGuid(", code, StringComparison.Ordinal);
        Assert.DoesNotContain("ToggleSelectAllCurrentPage", code, StringComparison.Ordinal);
    }

    [Fact]
    public void DynamicBatchGridView_RefreshesSelectedItemsWheneverTheFilteredViewChanges()
    {
        var code = ReadPwa("Shared", "DynamicBatchGridView.razor.cs");

        var applyStart = code.IndexOf("private void ApplyClientSideView()", StringComparison.Ordinal);
        Assert.True(applyStart >= 0, "ApplyClientSideView is missing.");
        var applyEnd = code.IndexOf("\n    }\n", applyStart, StringComparison.Ordinal);
        Assert.Contains("RefreshSelectedItems();", code[applyStart..applyEnd], StringComparison.Ordinal);
    }

    [Fact]
    public void DynamicBatchGridView_GridActionsReportProgressAndStillStopAtFirstFailure()
    {
        var code = ReadPwa("Shared", "DynamicBatchGridView.razor.cs");

        Assert.Contains("var result = await BulkOperationRunner.RunAsync(", code, StringComparison.Ordinal);
        Assert.Contains("stopOnFirstFailure: true);", code, StringComparison.Ordinal);
        Assert.Contains("GridActionProgress = progress;", code, StringComparison.Ordinal);
    }

    [Fact]
    public void BulkRecordChange_RunsThroughTheRunnerAndTreatsUpsertMessagesAsFailures()
    {
        var source = ReadPwa("Pages", "BulkRecordChange.razor");

        Assert.Contains("Result = await BulkOperationRunner.RunAsync(", source, StringComparison.Ordinal);
        Assert.Contains("cancellationToken: _cancellation.Token);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("stopOnFirstFailure", source, StringComparison.Ordinal);

        // UpsertDataObject returns errors/validation failures as a message instead of throwing.
        Assert.Contains("var (upsertMessage, _) = await formHelper.UpsertDataObject(dataObject, null, false);", source, StringComparison.Ordinal);
        Assert.Contains("throw new InvalidOperationException(upsertMessage);", source, StringComparison.Ordinal);

        // Only a clean run with nothing skipped closes the window; otherwise the summary stays up.
        Assert.Contains("if (Result.IsCompleteSuccess && Result.Skipped == 0)", source, StringComparison.Ordinal);
        Assert.Contains("(!Result.IsCompleteSuccess || Result.Skipped > 0)", source, StringComparison.Ordinal);
        Assert.Contains("@foreach (var failure in Result.Failures)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void BulkRecordChange_SkipsRecordsWithNoWritableFieldsAndConfirmsInPage()
    {
        var source = ReadPwa("Pages", "BulkRecordChange.razor");

        // A record whose chosen fields are all read-only (e.g. a completed activity) is not saved
        // and is reported as skipped, not as updated.
        Assert.Contains("if (ApplyBulkValues(dataObject, ValuesToSet) == 0) return BulkItemOutcome.Skipped;", source, StringComparison.Ordinal);

        // A native confirm()/alert() blocks the whole page until dismissed.
        Assert.DoesNotContain("InvokeAsync<bool>(\"confirm\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("InvokeVoidAsync(\"alert\"", source, StringComparison.Ordinal);
        Assert.Contains("@onclick=\"ApplyChangesAsync\"", source, StringComparison.Ordinal);
    }

    [Fact]
    public void BulkRecordChange_OverlaysAreClickable()
    {
        // EditPage.razor's global `.overlay { pointer-events: none; }` also matched these overlays, so
        // Stop, Apply changes, Cancel and Close could not be clicked (release/26.4 retest on
        // CymBuild_Dev264). They use their own class, which re-enables pointer events.
        var source = ReadPwa("Pages", "BulkRecordChange.razor");

        Assert.DoesNotContain("class=\"overlay\"", source, StringComparison.Ordinal);
        Assert.Equal(3, source.Split("<div class=\"bulk-change-overlay\">").Length - 1);

        var rule = source.IndexOf(".bulk-change-overlay {", StringComparison.Ordinal);
        Assert.True(rule >= 0, ".bulk-change-overlay rule not found.");
        var body = source[rule..source.IndexOf('}', rule)];
        Assert.Contains("pointer-events: auto;", body, StringComparison.Ordinal);
    }

    private static string ReadPwa(params string[] relativePath) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(["apps", "Concursus.PWA", .. relativePath]))
            .Replace("\r\n", "\n");
}
