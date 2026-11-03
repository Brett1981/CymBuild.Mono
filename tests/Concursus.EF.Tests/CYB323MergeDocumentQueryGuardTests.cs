using Concursus.EF;
using Xunit;

namespace Concursus.EF.Tests;

/// <summary>
/// CYB-323: GetQuoteConsultantSignatoryInfo, GetGatingRulesForMergeDocumentItem and
/// GetQuoteItemMergeLines all open a real SQL connection once past their default-Guid
/// guard, so only that guard branch is safe to exercise here with no database - the actual
/// query paths need SQL integration tests (CymBuild.Database.IntegrationTests) instead. Those
/// do not currently exist: Quotes/QuoteItems/MergeDocumentItemGatingProducts are not stubbed
/// in the R4 SQL test fixtures (only SCore.Identities is) - see the Phase 1 plan doc.
/// </summary>
public sealed class CYB323MergeDocumentQueryGuardTests
{
    private const string DummyConnectionString =
        "Server=(localdb)\\MSSQLLocalDB;Database=CymBuild_Test_Unused;Integrated Security=True;";

    [Fact]
    public async Task GetQuoteConsultantSignatoryInfo_ReturnsEmptyForDefaultGuidWithoutOpeningConnection()
    {
        var core = new Core(DummyConnectionString, user: null!);

        var result = await core.GetQuoteConsultantSignatoryInfo(Guid.Empty);

        Assert.Empty(result);
    }

    [Fact]
    public async Task GetGatingRulesForMergeDocumentItem_ReturnsEmptyForDefaultGuidWithoutOpeningConnection()
    {
        var core = new Core(DummyConnectionString, user: null!);

        var result = await core.GetGatingRulesForMergeDocumentItem(Guid.Empty);

        Assert.Empty(result);
    }

    [Fact]
    public async Task GetQuoteItemMergeLines_ReturnsEmptyForDefaultGuidWithoutOpeningConnection()
    {
        var core = new Core(DummyConnectionString, user: null!);

        var result = await core.GetQuoteItemMergeLines(Guid.Empty);

        Assert.Empty(result);
    }
}
