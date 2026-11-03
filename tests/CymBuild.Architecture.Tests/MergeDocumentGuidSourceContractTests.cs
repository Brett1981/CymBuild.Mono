using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// Since "Defer Merge Document Hydration" (af2a72c7) the PWA no longer sends a merge document's
/// items with its header; the API loads them on demand by the merge document's Guid. The document
/// menu built that header without DocumentGuid, so the Guid arrived empty and every Include, Data
/// Table and Signature item was silently skipped at generation.
/// </summary>
public sealed class MergeDocumentGuidSourceContractTests
{
    [Fact]
    public void DocumentTaskView_SendsTheMergeDocumentGuidWithEachMenuItem()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Pages", "DocumentTaskView.razor.cs"));

        // The menu item must carry the merge document's Guid...
        Assert.Contains("DocumentGuid = item.Guid,", source, StringComparison.Ordinal);

        // ...and the generation request must forward it as the MergeDocument's Guid.
        Assert.Contains(
            "Guid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(menuItem.DocumentGuid).ToString(),",
            source,
            StringComparison.Ordinal);
    }
}
