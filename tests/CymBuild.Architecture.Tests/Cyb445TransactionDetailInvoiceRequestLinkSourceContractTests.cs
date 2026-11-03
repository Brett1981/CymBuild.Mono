using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-445: SFin.TransactionDetailsUpsert must not wipe TransactionDetails.InvoiceRequestItemId when
// a caller (e.g. the Transaction Detail form) omits the optional @InvoiceRequestItemGuid. The fix
// shipped to LIVE in 26.2 (dce858c4) but was missing from release/26.4, so the invoice request item
// was unlinked (-1) on every edit and the request reappeared as unprocessed. Pinned here so a stale
// DEV schema sync fails the fast suite instead of reaching a release.
public sealed class Cyb445TransactionDetailInvoiceRequestLinkSourceContractTests
{
    [Fact]
    public void Update_PreservesTheExistingInvoiceRequestItemLinkWhenNoGuidIsSupplied()
    {
        var sql = ReadProcedure();

        Assert.Contains("@HasInvoiceRequestItemGuid  BIT    = 0", sql, StringComparison.Ordinal);
        Assert.Contains("SET @HasInvoiceRequestItemGuid = 1;", sql, StringComparison.Ordinal);
        Assert.Contains("ELSE td.InvoiceRequestItemId", sql, StringComparison.Ordinal);
        Assert.DoesNotContain("td.InvoiceRequestItemId = ISNULL(@InvoiceRequestItemID, -1)", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void SuppliedGuidThatDoesNotResolve_IsRejected()
    {
        var sql = ReadProcedure();

        var flag = sql.IndexOf("SET @HasInvoiceRequestItemGuid = 1;", StringComparison.Ordinal);
        var guard = sql.IndexOf("THROW 60076", StringComparison.Ordinal);
        var write = sql.IndexOf("INSERT SFin.TransactionDetails", StringComparison.OrdinalIgnoreCase);
        if (write < 0)
        {
            write = sql.IndexOf("INSERT INTO SFin.TransactionDetails", StringComparison.OrdinalIgnoreCase);
        }

        Assert.True(flag >= 0 && guard > flag, "An unresolved @InvoiceRequestItemGuid must throw 60076.");
        Assert.True(write < 0 || guard < write, "The 60076 guard must run before TransactionDetails is written.");
    }

    private static string ReadProcedure() =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["Database", "CymBuild_DB", "Schema", "Programmability", "Procedures", "SFin.TransactionDetailsUpsert.sql"]));
}
