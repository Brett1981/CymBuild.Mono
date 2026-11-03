using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-389: GridViewDefinitions.AllowCsvExport drives the "Export CSV" button on standard
// (GridViewTypeId 1) grids. DynamicGridView lives in the PWA (no bUnit host), so the visibility
// rule is pinned as a source contract, matching the other DynamicGridView tests in this project.
public sealed class Cyb389GridCsvExportSourceContractTests
{
    [Fact]
    public void DynamicGridView_ShowsCsvExportButtonWhenMetadataAllowsIt()
    {
        var codeBehind = ReadPwaSharedFile("DynamicGridView.razor.cs");
        var rule = ExtractCsvButtonRule(codeBehind);

        Assert.Contains("ViewDefinition.AllowCsvExport ||", rule, StringComparison.Ordinal);
    }

    [Fact]
    public void DynamicGridView_KeepsLegacyHardCodedCsvExportGrids()
    {
        var codeBehind = ReadPwaSharedFile("DynamicGridView.razor.cs");
        var rule = ExtractCsvButtonRule(codeBehind);

        // Existing grids showed CSV export without the metadata flag; they must keep it.
        foreach (var code in new[] { "OVERDUEACTIVITIES", "ENGJOBSFINANCE", "OVERDUEMILESTONES" })
        {
            Assert.Contains($"\"{code}\"", rule, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void DynamicGridView_CsvExportButtonIsGatedByTheRule()
    {
        var razor = ReadPwaSharedFile("DynamicGridView.razor");

        Assert.Contains("@if (ShouldShowCsvExportButton)", razor, StringComparison.Ordinal);
        Assert.Contains("@onclick=\"ExportToCsvWithOptions\"", razor, StringComparison.Ordinal);
    }

    [Fact]
    public void AllowCsvExport_FlowsFromSqlToTheClientDefinition()
    {
        var tvf = File.ReadAllText(RepositoryLayout.PathFromRoot("Database", "CymBuild_DB", "Schema", "Programmability", "Functions", "SUserInterface.tvf_GridViewDefinitions.sql"));
        Assert.Contains("gvd.[AllowCsvExport] AS [AllowCsvExport]", tvf, StringComparison.Ordinal);

        var proto = File.ReadAllText(RepositoryLayout.PathFromRoot("services", "Concursus.API", "Protos", "core.proto"));
        Assert.Contains("bool AllowCsvExport = 51;", proto, StringComparison.Ordinal);

        var converters = File.ReadAllText(RepositoryLayout.PathFromRoot("services", "Concursus.API", "Classes", "Converters.cs"));
        Assert.Contains("AllowCsvExport = request.AllowCsvExport", converters, StringComparison.Ordinal);
    }

    private static string ExtractCsvButtonRule(string codeBehind)
    {
        const string start = "private bool ShouldShowCsvExportButton =>";
        var startIndex = codeBehind.IndexOf(start, StringComparison.Ordinal);
        Assert.True(startIndex >= 0, "ShouldShowCsvExportButton was not found in DynamicGridView.razor.cs.");

        var endIndex = codeBehind.IndexOf(';', startIndex);
        Assert.True(endIndex > startIndex, "ShouldShowCsvExportButton has no terminating semicolon.");

        return codeBehind[startIndex..endIndex];
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
