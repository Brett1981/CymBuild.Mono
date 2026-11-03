using Concursus.Common.Shared.Models.Finance;
using Concursus.EF;
using Concursus.EF.Finance;
using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;
using System.Security.Claims;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-501: TransactionInvoicePreviewRepository opens its own connection (it isn't
/// given an ambient transaction), so — like JobClosureDecisionOutboxAtomicityTests'
/// second test — fixture rows are committed and removed explicitly in a finally
/// block rather than wrapped in a rolled-back transaction.
/// </summary>
public sealed class TransactionInvoicePreviewFallbackTests
{
    [Fact]
    public async Task PreviewMode_PrefersSageInvoiceNumberOverReservedWhenAlreadyKnown()
    {
        var database = SqlTestDatabase.FromEnvironment();
        SqlTestData.TransactionFixture fixture;

        await using (var connection = await database.OpenConnectionAsync())
        {
            var accountId = await SqlTestData.ReadActiveAccountIdAsync(connection, transaction: null);
            fixture = await SqlTestData.InsertTransactionFixtureAsync(
                connection,
                transaction: null,
                accountId,
                reservedInvoiceNumber: "RES-P501-010",
                sageInvoiceNumber: "DOC-777");
        }

        try
        {
            var repository = CreateRepository(database);

            var model = await repository.GetInvoicePrintModelAsync(
                fixture.TransactionGuid, TransactionInvoiceRenderMode.Preview);

            Assert.NotNull(model);
            Assert.Equal("DOC-777", model!.InvoiceNumber);
        }
        finally
        {
            await CleanupTransactionFixtureAsync(database, fixture.TransactionGuid);
        }
    }

    [Fact]
    public async Task PreviewMode_FallsBackToReservedInvoiceNumberWhenNoSageNumberYet()
    {
        var database = SqlTestDatabase.FromEnvironment();
        SqlTestData.TransactionFixture fixture;

        await using (var connection = await database.OpenConnectionAsync())
        {
            var accountId = await SqlTestData.ReadActiveAccountIdAsync(connection, transaction: null);
            fixture = await SqlTestData.InsertTransactionFixtureAsync(
                connection,
                transaction: null,
                accountId,
                reservedInvoiceNumber: "RES-P501-011");
        }

        try
        {
            var repository = CreateRepository(database);

            var model = await repository.GetInvoicePrintModelAsync(
                fixture.TransactionGuid, TransactionInvoiceRenderMode.Preview);

            Assert.NotNull(model);
            Assert.Equal("RES-P501-011", model!.InvoiceNumber);
        }
        finally
        {
            await CleanupTransactionFixtureAsync(database, fixture.TransactionGuid);
        }
    }

    [Fact]
    public async Task FinalMode_IsUnaffectedAndStaysEmptyWhenNoSageNumberYet()
    {
        var database = SqlTestDatabase.FromEnvironment();
        SqlTestData.TransactionFixture fixture;

        await using (var connection = await database.OpenConnectionAsync())
        {
            var accountId = await SqlTestData.ReadActiveAccountIdAsync(connection, transaction: null);
            fixture = await SqlTestData.InsertTransactionFixtureAsync(
                connection,
                transaction: null,
                accountId,
                reservedInvoiceNumber: "RES-P501-012");
        }

        try
        {
            var repository = CreateRepository(database);

            var model = await repository.GetInvoicePrintModelAsync(
                fixture.TransactionGuid, TransactionInvoiceRenderMode.Final);

            Assert.NotNull(model);
            Assert.Equal(string.Empty, model!.InvoiceNumber);
        }
        finally
        {
            await CleanupTransactionFixtureAsync(database, fixture.TransactionGuid);
        }
    }

    private static TransactionInvoicePreviewRepository CreateRepository(SqlTestDatabase database)
    {
        var core = new Core(database.ConnectionString, new ClaimsPrincipal(new ClaimsIdentity()));
        return new TransactionInvoicePreviewRepository(core);
    }

    private static async Task CleanupTransactionFixtureAsync(SqlTestDatabase database, Guid transactionGuid)
    {
        // A SqlParameter instance can only belong to one SqlCommand at a time, so each
        // ExecuteNonQueryAsync call below needs its own parameter instance.
        static SqlParameter TransactionGuidParameter(Guid guid) =>
            new("@Guid", SqlDbType.UniqueIdentifier) { Value = guid };

        await database.ExecuteNonQueryAsync(
            """
            DELETE td
            FROM SFin.TransactionDetails AS td
            JOIN SFin.Transactions AS t ON t.ID = td.TransactionID
            WHERE t.Guid = @Guid;
            """,
            new[] { TransactionGuidParameter(transactionGuid) });
        await database.ExecuteNonQueryAsync(
            "DELETE FROM SFin.Transactions WHERE Guid = @Guid;",
            new[] { TransactionGuidParameter(transactionGuid) });
        await database.ExecuteNonQueryAsync(
            "DELETE FROM SCore.DataObjects WHERE Guid = @Guid;",
            new[] { TransactionGuidParameter(transactionGuid) });
    }
}
