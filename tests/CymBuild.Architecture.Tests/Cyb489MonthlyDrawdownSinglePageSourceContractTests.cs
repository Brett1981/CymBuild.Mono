using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-489 (LIVE 26.2 fix c24d3cb7, missing from release/26.4): monthly drawdowns are edited inline
// across the whole schedule, and changing page reloads the rows, so edits made on page 1 were lost
// after visiting page 2. The monthly drawdown grid must always load on one page (at least 150 rows).
public sealed class Cyb489MonthlyDrawdownSinglePageSourceContractTests
{
    [Fact]
    public void MonthlyDrawdownGrid_AlwaysLoadsEveryDrawdownOnOnePage()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["apps", "Concursus.PWA", "Shared", "DynamicGridView.razor.cs"]));

        Assert.Contains("private const int MonthlyDrawdownPageSize = 150;", source, StringComparison.Ordinal);

        var guard = source.IndexOf("if (IsMonthlyDrawdownGrid)\r\n", StringComparison.Ordinal);
        if (guard < 0) guard = source.IndexOf("if (IsMonthlyDrawdownGrid)\n", StringComparison.Ordinal);
        var request = source.IndexOf("var request = new GridDataListRequest", guard, StringComparison.Ordinal);

        Assert.True(guard >= 0 && request > guard, "The single-page rule must run before the grid data request is built.");

        var body = source[guard..request];
        Assert.Contains("_pageSize = Math.Max(_pageSize, MonthlyDrawdownPageSize);", body, StringComparison.Ordinal);
        Assert.Contains("_page = 1;", body, StringComparison.Ordinal);
    }
}
