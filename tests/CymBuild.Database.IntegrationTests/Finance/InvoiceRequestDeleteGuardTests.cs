using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-574: SFin.InvoiceRequestsDelete refuses a "completed" request using the same test
/// SFin.tvf_InvoiceRequests uses to hide it from the Finance grid - an active line on an active
/// transaction. A request whose transaction was soft-deleted shows in that grid again, so it
/// must also be deletable (QA2: request 2277 showed but could not be deleted).
/// </summary>
public sealed class InvoiceRequestDeleteGuardTests
{
    private const byte Active = 1;
    private const byte SoftDeleted = 254;
    private const byte TransactionStatus200 = 200;

    [Theory]
    [InlineData(Active, Active, true)]
    [InlineData(Active, SoftDeleted, false)]
    [InlineData(Active, TransactionStatus200, false)]
    [InlineData(SoftDeleted, Active, false)]
    public async Task InvoiceRequestsDelete_BlocksOnlyAnActiveLineOnAnActiveTransaction(
        byte lineRowStatus,
        byte transactionRowStatus,
        bool expectBlocked)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var (requestGuid, itemId) = await InsertInvoiceRequestWithItemAsync(connection, transaction);
            var accountId = await SqlTestData.ReadActiveAccountIdAsync(connection, transaction);
            var fixture = await SqlTestData.InsertTransactionFixtureAsync(
                connection,
                transaction,
                accountId,
                reservedInvoiceNumber: "RES-CYB574-DEL");

            const string linkSql = """
UPDATE SFin.TransactionDetails
SET InvoiceRequestItemId = @ItemId,
    RowStatus = @LineRowStatus
WHERE TransactionID = @TransactionId;

UPDATE SFin.Transactions
SET RowStatus = @TransactionRowStatus
WHERE ID = @TransactionId;
""";
            await using (var link = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                linkSql,
                new[]
                {
                    new SqlParameter("@ItemId", SqlDbType.BigInt) { Value = itemId },
                    new SqlParameter("@LineRowStatus", SqlDbType.TinyInt) { Value = lineRowStatus },
                    new SqlParameter("@TransactionRowStatus", SqlDbType.TinyInt) { Value = transactionRowStatus },
                    new SqlParameter("@TransactionId", SqlDbType.BigInt) { Value = fixture.TransactionId }
                }))
            {
                await link.ExecuteNonQueryAsync();
            }

            if (expectBlocked)
            {
                // XACT_ABORT in the procedure rolls the test transaction back with the error, so
                // the refusal itself is the assertion.
                var error = await Assert.ThrowsAsync<SqlException>(() => ExecuteDeleteAsync(connection, transaction, requestGuid));
                Assert.Equal(60000, error.Number);
                Assert.Contains("Cannot delete a completed invoice request.", error.Message, StringComparison.Ordinal);
            }
            else
            {
                await ExecuteDeleteAsync(connection, transaction, requestGuid);
                Assert.Equal(SoftDeleted, await ReadRequestRowStatusAsync(connection, transaction, requestGuid));
            }
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task InvoiceRequestsDelete_DeletesARequestWithNoTransaction()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var (requestGuid, _) = await InsertInvoiceRequestWithItemAsync(connection, transaction);

            await ExecuteDeleteAsync(connection, transaction, requestGuid);

            Assert.Equal(SoftDeleted, await ReadRequestRowStatusAsync(connection, transaction, requestGuid));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    private static async Task<(Guid RequestGuid, long ItemId)> InsertInvoiceRequestWithItemAsync(
        SqlConnection connection,
        SqlTransaction transaction)
    {
        var requestGuid = Guid.NewGuid();

        const string sql = """
DECLARE @RequestId INT;

INSERT INTO SFin.InvoiceRequests (RowStatus, Guid, Notes)
VALUES (1, @RequestGuid, N'CYB-574 delete guard fixture');

SET @RequestId = SCOPE_IDENTITY();

INSERT INTO SFin.InvoiceRequestItems (RowStatus, Guid, InvoiceRequestId)
OUTPUT INSERTED.ID
VALUES (1, NEWID(), @RequestId);
""";

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[] { new SqlParameter("@RequestGuid", SqlDbType.UniqueIdentifier) { Value = requestGuid } });
        var itemId = Convert.ToInt64(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);

        return (requestGuid, itemId);
    }

    private static async Task ExecuteDeleteAsync(SqlConnection connection, SqlTransaction transaction, Guid requestGuid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SFin.InvoiceRequestsDelete",
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = requestGuid } });
        command.CommandType = CommandType.StoredProcedure;
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<byte> ReadRequestRowStatusAsync(SqlConnection connection, SqlTransaction transaction, Guid requestGuid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SELECT RowStatus FROM SFin.InvoiceRequests WHERE Guid = @Guid;",
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = requestGuid } });
        return Convert.ToByte(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }
}
