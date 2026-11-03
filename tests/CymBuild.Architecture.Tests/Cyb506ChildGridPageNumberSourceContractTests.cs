using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-506 (LIVE 26.2 fix fa766c6c, missing from release/26.4): DynamicGridView saves the current
// page under "{ViewDefinition.Code}_currentPageNumber", a key with no record in it. A child grid
// (e.g. Job Fees > Transactions) therefore reopened on the page used for another record and looked
// empty. Every read and write of that key must be gated so only full, parentless grids persist it.
public sealed class Cyb506ChildGridPageNumberSourceContractTests
{
    [Fact]
    public void OnlyFullParentlessGridsPersistTheirPageNumber()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["apps", "Concursus.PWA", "Shared", "DynamicGridView.razor.cs"]));

        Assert.Contains(
            "FullGrid && PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid) == Guid.Empty",
            source,
            StringComparison.Ordinal);

        var accesses = Regex.Matches(
            source,
            @"LocalStorageAccessor\.(Get|Set)Value(Async)?(<[^>]+>)?\(\$""\{ViewDefinition\.Code\}_currentPageNumber""",
            RegexOptions.CultureInvariant);

        Assert.NotEmpty(accesses);
        foreach (Match access in accesses)
        {
            // The guard must sit within the few lines before each access.
            var window = source.Substring(Math.Max(0, access.Index - 200), Math.Min(200, access.Index));
            Assert.Contains("PersistsPageNumber", window, StringComparison.Ordinal);
        }
    }
}
