using Concursus.EF;
using Xunit;

namespace Concursus.EF.Tests;

/// <summary>
/// TransactionRejectBatchedAsync opens a real SQL connection once past its Guid.Empty guard, so
/// only that guard branch is safe to exercise here with no database - the stored-procedure call
/// path needs the SQL integration tests (CymBuild.Database.IntegrationTests) instead.
/// </summary>
public sealed class TransactionRejectBatchedAsyncTests
{
    private const string DummyConnectionString =
        "Server=(localdb)\\MSSQLLocalDB;Database=CymBuild_Test_Unused;Integrated Security=True;";

    [Fact]
    public async Task TransactionRejectBatchedAsync_RejectsEmptyGuidWithoutOpeningConnection()
    {
        var core = new Core(DummyConnectionString, user: null!);

        var result = await core.TransactionRejectBatchedAsync(
            Guid.Empty,
            "Duplicate entry",
            TestContext.Current.CancellationToken);

        Assert.False(result.Success);
        Assert.Equal(
            "A valid Transaction Guid is required to reject a batched transaction.",
            result.ErrorReturned);
    }
}
