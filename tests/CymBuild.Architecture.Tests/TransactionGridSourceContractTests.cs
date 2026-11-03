using Xunit;

namespace CymBuild.Architecture.Tests;

public sealed class TransactionGridSourceContractTests
{
    [Fact]
    public void WordAssemblyPackage_MatchesTheNet10OpenXmlAndSkiaStack()
    {
        var project = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "libs",
                "Concursus.Common.Shared",
                "Concursus.Common.Shared.csproj"));

        Assert.Contains(
            "<PackageReference Include=\"Codeuctivity.OpenXmlPowerTools\" Version=\"10.0.621\" />",
            project,
            StringComparison.Ordinal);
        Assert.DoesNotContain(
            "<PackageReference Include=\"OpenXmlPowerTools\"",
            project,
            StringComparison.Ordinal);
    }

    [Fact]
    public void AllTransactions_PreservesExtendedColumnsAndPaymentStatusRules()
    {
        var sql = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "Database",
                "CymBuild_DB",
                "Schema",
                "Programmability",
                "Functions",
                "SFin.tvf_AllTransactions.sql"));

        Assert.Contains("CREATE OR ALTER FUNCTION [SFin].[tvf_AllTransactions]", sql, StringComparison.Ordinal);
        Assert.Contains("j.Number AS JobNumber", sql, StringComparison.Ordinal);
        Assert.Contains("j.JobDescription", sql, StringComparison.Ordinal);
        Assert.Contains("Prods.Products", sql, StringComparison.Ordinal);
        Assert.Contains("STRING_AGG(d.Code, ',') AS Products", sql, StringComparison.Ordinal);
        Assert.Contains("qi.RowStatus NOT IN (0,254)", sql, StringComparison.Ordinal);
        Assert.Contains("tc.Outstanding > 0", sql, StringComparison.Ordinal);
        Assert.Contains("sageInbound.MaterialisedReceiptTransactionGuid = t.Guid", sql, StringComparison.Ordinal);
        Assert.Contains("THEN N'Received from Sage'", sql, StringComparison.Ordinal);
        Assert.Contains("THEN N'Manual'", sql, StringComparison.Ordinal);
        Assert.DoesNotContain("SELECT *", sql, StringComparison.OrdinalIgnoreCase);

        var inboundStatus = sql.IndexOf("WHEN SageInbound.IsSageInbound = 1", StringComparison.Ordinal);
        var succeededStatus = sql.IndexOf("WHEN s.StatusCode = N'Succeeded'", StringComparison.Ordinal);
        var legacyStatus = sql.IndexOf("WHEN legacy.HasActiveManualSageExport = 1", StringComparison.Ordinal);
        var manualStatus = sql.IndexOf("THEN N'Manual'", StringComparison.Ordinal);
        var notSentStatus = sql.IndexOf("WHEN s.StatusCode IS NULL", StringComparison.Ordinal);

        Assert.True(inboundStatus >= 0, "The Sage inbound receipt status rule is missing.");
        Assert.True(
            succeededStatus > inboundStatus,
            "Successful automated submissions must remain classified as Succeeded.");
        Assert.True(
            legacyStatus > succeededStatus,
            "Active historical Sage exports must remain classified as Legacy.");
        Assert.True(
            manualStatus > legacyStatus,
            "A Sage reference must be classified as Manual without relabelling historical Sage exports.");
        Assert.True(
            notSentStatus > manualStatus,
            "Manual transactions must be classified before the Not Sent fallback.");
    }

    [Fact]
    public void TransactionGrid_TrustsTheServerProvidedSageStatus()
    {
        var source = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "Shared",
                "FilteredDynamicGridView.razor.cs"));

        Assert.Contains("case \"RECEIVED FROM SAGE\":", source, StringComparison.Ordinal);
        Assert.Contains("DisplayText = \"Received from Sage\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "A Sage reference is authoritative legacy evidence",
            source,
            StringComparison.Ordinal);
    }

    [Fact]
    public void InvoicePreview_UsesExactA4LayoutAndRejectsOverflow()
    {
        var razor = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "Shared",
                "InvoicePrintTemplate.razor"));
        var css = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "Shared",
                "InvoicePrintTemplate.razor.css"));
        var index = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "wwwroot",
                "index.html"));

        Assert.Contains("CUSTOMER REFERENCE: @Model.CustomerReference", razor, StringComparison.Ordinal);
        Assert.Contains("INVOICE No. @Model.InvoiceNumber", razor, StringComparison.Ordinal);
        Assert.Contains("<td class=\"detail-header-cell center\">CODE</td>", razor, StringComparison.Ordinal);
        Assert.Contains("grid-template-rows: auto auto minmax(0, 1fr) auto auto", css, StringComparison.Ordinal);
        Assert.Contains("size: A4 portrait", css, StringComparison.Ordinal);
        Assert.Contains("page.scrollHeight > pageHeight + 2", index, StringComparison.Ordinal);
        Assert.Contains("did not render at the A4 aspect ratio", index, StringComparison.Ordinal);
    }
}
