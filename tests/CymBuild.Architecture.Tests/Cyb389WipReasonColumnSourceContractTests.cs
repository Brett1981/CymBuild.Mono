using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-389: the WIP reason was only visible inside each invoice request, not in the Finance
/// "Invoice Requests (WIP)" grid. The grid's TVF must return WIPReason, and the grid column is added
/// by an idempotent, Guid-only metadata script that goes through the column upsert procedure (so the
/// SCore.DataObjects row is created with it) and reuses the form field's existing label.
/// </summary>
public sealed class Cyb389WipReasonColumnSourceContractTests
{
    private const string GridViewGuid = "FC756AD7-E56E-40F0-85E0-0F4408544C4B";
    private const string ColumnGuid = "B29C12D0-2DB9-4517-BBF5-5C28A3769DD5";
    private const string WipReasonLabelGuid = "86FE124C-ECE6-4744-A8FF-5602710F19F7";

    [Fact]
    public void InvoiceRequestsWipTvf_ReturnsAndGroupsByWipReason()
    {
        var source = Read("Database", "CymBuild_DB", "Schema", "Programmability", "Functions", "SFin.tvf_InvoiceRequestsWIP.sql");
        var groupBy = source.LastIndexOf("GROUP BY", StringComparison.OrdinalIgnoreCase);

        Assert.True(groupBy > 0, "GROUP BY not found.");
        Assert.Contains("ir.WIPReason", source[..groupBy], StringComparison.Ordinal);
        Assert.Contains("ir.WIPReason", source[groupBy..], StringComparison.Ordinal);
    }

    [Fact]
    public void WipReasonColumnScript_IsGuidOnlyAndUsesTheColumnUpsert()
    {
        var source = Read("Database", "CymBuild_DB", "Scripts", "Upgrade Scripts", "CYB-389_WIP_Reason_GridColumn.sql");

        Assert.Contains($"@GridViewGuid    UNIQUEIDENTIFIER = '{GridViewGuid}'", source, StringComparison.Ordinal);
        Assert.Contains($"@ColumnGuid      UNIQUEIDENTIFIER = '{ColumnGuid}'", source, StringComparison.Ordinal);
        Assert.Contains($"@LabelGuid       UNIQUEIDENTIFIER = '{WipReasonLabelGuid}'", source, StringComparison.Ordinal);
        Assert.Contains("EXEC SUserInterface.GridViewColumnDefinitionUpsert", source, StringComparison.Ordinal);
        Assert.Contains("@Name                   = N'WIPReason'", source, StringComparison.Ordinal);

        // No direct inserts and no environment-specific numeric ids.
        Assert.DoesNotContain("INSERT INTO SUserInterface.GridViewColumnDefinitions", source, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("INSERT SUserInterface.GridViewColumnDefinitions", source, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("GridViewDefinitionId =", source, StringComparison.OrdinalIgnoreCase);
    }

    private static string Read(params string[] relativePath) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(relativePath)).Replace("\r\n", "\n");
}
