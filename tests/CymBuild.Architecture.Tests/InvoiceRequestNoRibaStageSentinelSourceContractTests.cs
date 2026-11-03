using Xunit;

namespace CymBuild.Architecture.Tests;

// LIVE 26.2 fix dce858c4 (missing from release/26.4): invoice request items and the transaction
// details created from them must never carry a NULL RIBAStageId. No stage resolves to the -1
// no-RIBA-stage sentinel; a supplied stage Guid that does not resolve is refused. Pinned here so a
// stale DEV schema sync fails the fast suite instead of reaching a release.
public sealed class InvoiceRequestNoRibaStageSentinelSourceContractTests
{
    [Fact]
    public void InvoiceRequestItemsUpsert_DefaultsToTheSentinelAndRejectsAnUnknownStage()
    {
        var sql = ReadProcedure("SFin.InvoiceRequestItemsUpsert.sql");

        var sentinel = sql.IndexOf("SET @RIBAStageId = -1;", StringComparison.Ordinal);
        var unknownStage = sql.IndexOf("RIBAStageGuid not found.", StringComparison.Ordinal);
        var activityLookup = sql.IndexOf("@RIBASetOnActivityId", StringComparison.Ordinal);

        Assert.True(sentinel >= 0, "No RIBA stage must resolve to the -1 sentinel.");
        Assert.True(unknownStage > sentinel, "A supplied RIBA stage Guid that does not resolve must throw.");
        Assert.True(activityLookup > unknownStage, "The stage must be resolved before the Activity stage rules run.");
    }

    [Fact]
    public void InvoiceRequestCreateInvoice_NeverCopiesANullStageMilestoneOrActivity()
    {
        var sql = ReadProcedure("SFin.InvoiceRequestCreateInvoice.sql");

        Assert.Contains("COALESCE(iri.MilestoneId, -1)", sql, StringComparison.Ordinal);
        Assert.Contains("COALESCE(iri.ActivityId, -1)", sql, StringComparison.Ordinal);
        Assert.Contains("COALESCE(iri.RIBAStageId, -1)", sql, StringComparison.Ordinal);
    }

    private static string ReadProcedure(string fileName) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["Database", "CymBuild_DB", "Schema", "Programmability", "Procedures", fileName]));
}
