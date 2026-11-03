using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-553: the business asked IT to expire Shore CDM legacy enquiries/quotes that
// were never converted to a job, leave them out of reporting, and default their
// missing Org/BU - with no development fix for the historical jobs themselves.
public sealed class Cyb553ShoreLegacySourceContractTests
{
    [Fact]
    public void BulkScript_ChangesStatusOnlyThroughTheTransitionUpsert_AndPreviewsByDefault()
    {
        var sql = ReadScript();

        Assert.Contains("DECLARE @DryRun BIT = 1;", sql, StringComparison.Ordinal);
        Assert.Contains("EXEC SCore.DataObjectTransitionUpsert", sql, StringComparison.Ordinal);
        Assert.Contains("@StatusGuid        = @ExpiredStatusGuid", sql, StringComparison.Ordinal);
        // Workflow status is never written directly (AGENTS.md).
        Assert.DoesNotContain("INSERT INTO SCore.DataObjectTransition", sql, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("UPDATE SCore.DataObjectTransition", sql, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("SELECT *", sql, StringComparison.OrdinalIgnoreCase);

        var dryRunReturn = sql.IndexOf("IF @DryRun = 1", StringComparison.Ordinal);
        var firstWrite = sql.IndexOf("EXEC SCore.DataObjectTransitionUpsert", StringComparison.Ordinal);
        Assert.True(dryRunReturn >= 0 && dryRunReturn < firstWrite, "The dry run must return before anything is written.");
    }

    [Fact]
    public void BulkScript_FillsOnlyAMissingOrgUnit_AndOnlyExpiresNeverConvertedOpenRecords()
    {
        var sql = ReadScript();

        Assert.Equal(3, CountOccurrences(sql, "WHERE q.OrganisationalUnitID = -1;")
            + CountOccurrences(sql, "WHERE e.OrganisationalUnitID = -1;")
            + CountOccurrences(sql, "WHERE j.OrganisationalUnitID = -1;"));
        Assert.Contains("@DefaultOrgUnitGuid UNIQUEIDENTIFIER = '2C9489BD-EAE8-4703-90D7-56C94E802EDA'", sql, StringComparison.Ordinal);
        Assert.Contains("WHERE sq.HasJob = 0\n  AND sq.IsOpen = 1;", sql.Replace("\r\n", "\n"), StringComparison.Ordinal);
        Assert.Contains("(N'Expired'), (N'Quote Expired'), (N'Rejected')", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void BulkScript_MovesOnlyTheListedQuotesStillOnBuildingAndRealEstateAdmin_ToBuildingControlConsultancy()
    {
        var sql = ReadScript();

        Assert.Contains("@BccFromOrgUnitGuid UNIQUEIDENTIFIER = 'F233BB03-3181-49AE-B331-39C58F328457'", sql, StringComparison.Ordinal);
        Assert.Contains("@BccOrgUnitGuid UNIQUEIDENTIFIER = '0125329F-003B-4CE4-A2C9-8C6DCC1A4DFF'", sql, StringComparison.Ordinal);
        // Matched by the business keys, never by environment-specific IDs.
        Assert.Contains("ON q.Number = bq.Number\n   AND ISNULL(q.RevisionNumber, 0) = bq.RevisionNumber", sql.Replace("\r\n", "\n"), StringComparison.Ordinal);
        Assert.Contains("WHERE bq.WillMove = 1\n      AND q.OrganisationalUnitID = @BccFromOrgUnitID;", sql.Replace("\r\n", "\n"), StringComparison.Ordinal);
        Assert.Equal(24, CountOccurrences(sql.Substring(sql.IndexOf("INSERT INTO @BccQuotes", StringComparison.Ordinal), 900), "(N'"));
    }

    [Theory]
    [InlineData("SSop.Quotes_DWETL.sql")]
    [InlineData("SSop.Enquiries_DWETL.sql")]
    public void Reporting_LeavesOutExpiredNeverConvertedShoreRecords(string viewFile)
    {
        var sql = File.ReadAllText(RepositoryLayout.PathFromRoot("Database", "CymBuild_DB", "Schema", "Views", viewFile));

        Assert.Contains("CYB-553-SHORE-LEGACY-EXCLUSION", sql, StringComparison.Ordinal);
        Assert.Contains("LegacySystemID = 1", sql, StringComparison.Ordinal);
        Assert.Contains("CreatedJobId > 0", sql, StringComparison.Ordinal);
        Assert.Contains("'E6FAC201-F98B-4B3A-AB55-83DC9F802D00' -- Expired", sql, StringComparison.Ordinal);
    }

    private static string ReadScript()
    {
        return File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "Database",
                "CymBuild_DB",
                "Scripts",
                "Upgrade Scripts",
                "CYB-553_ShoreLegacy_ExpireAndDefaultOrgUnit.sql"));
    }

    private static int CountOccurrences(string text, string value)
    {
        var count = 0;
        for (var index = text.IndexOf(value, StringComparison.Ordinal); index >= 0; index = text.IndexOf(value, index + value.Length, StringComparison.Ordinal))
        {
            count++;
        }

        return count;
    }
}
