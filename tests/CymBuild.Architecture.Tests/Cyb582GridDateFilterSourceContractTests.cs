using Xunit;

namespace CymBuild.Architecture.Tests;

public sealed class Cyb582GridDateFilterSourceContractTests
{
    // CYB-582: a date column filter must match the picked day only, not "on or before" it.
    [Theory]
    [InlineData("DynamicGridView.razor.cs")]
    [InlineData("FilteredDynamicGridView.razor.cs")]
    [InlineData("FilteredDynamicGridViewV2.razor.cs")]
    public void DateColumnFilter_MatchesPickedDayOnly(string fileName)
    {
        var codeBehind = ReadPwaSharedFile(fileName);

        Assert.DoesNotContain("IsDateFilterColumn(filter.Key) ? \"le\"", codeBehind, StringComparison.Ordinal);
        Assert.DoesNotContain("IsDateFilterColumn(filter.ColumnName) ? \"le\"", codeBehind, StringComparison.Ordinal);

        Assert.Contains("\"yyyy-MM-dd\", CultureInfo.InvariantCulture, DateTimeStyles.None, out var day", codeBehind, StringComparison.Ordinal);
        Assert.Contains("\"ge\"", codeBehind, StringComparison.Ordinal);
        Assert.Contains("day.AddDays(1)", codeBehind, StringComparison.Ordinal);
        Assert.Contains("\"lt\"", codeBehind, StringComparison.Ordinal);
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
