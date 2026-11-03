using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-501: covers the two new/changed stored procedures that pull the Sage
/// document number through to CymBuild and correct pre-automation legacy
/// transaction statuses.
/// </summary>
public sealed class SageDocumentNumberPullThroughTests
{
    [Fact]
    public async Task TransactionSageInvoiceDetailsUpsert_PartialUpdate_PreservesUnsuppliedColumn()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var accountId = await SqlTestData.ReadActiveAccountIdAsync(connection, transaction);
            var fixture = await SqlTestData.InsertTransactionFixtureAsync(
                connection,
                transaction,
                accountId,
                reservedInvoiceNumber: "RES-P501-001",
                sageSalesOrderNumber: "SO-EXISTING");

            await SqlTestData.ExecuteTransactionSageInvoiceDetailsUpsertAsync(
                connection,
                transaction,
                fixture.TransactionGuid,
                sageInvoiceNumber: "DOC-500",
                sageSalesOrderNumber: null);

            const string sql = """
SELECT SageInvoiceNumber, SageSalesOrderNumber
FROM SFin.Transactions
WHERE Guid = @Guid;
""";
            await using var command = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                sql,
                new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = fixture.TransactionGuid } });
            await using var reader = await command.ExecuteReaderAsync();

            Assert.True(await reader.ReadAsync());
            Assert.Equal("DOC-500", reader.GetString(0));
            Assert.Equal("SO-EXISTING", reader.GetString(1));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task MarkSentLegacy_TransitionsPendingRowWithPriorSageEvidence()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var accountId = await SqlTestData.ReadActiveAccountIdAsync(connection, transaction);
            var fixture = await SqlTestData.InsertTransactionFixtureAsync(
                connection,
                transaction,
                accountId,
                reservedInvoiceNumber: "RES-P501-002",
                sageTransactionReference: "TR-LEGACY-001");
            var statusId = await SqlTestData.InsertTransactionSageSubmissionStatusAsync(
                connection, transaction, fixture.TransactionId, fixture.TransactionGuid, "Pending");

            await using (var command = SqlTestDatabase.CreateCommand(
                connection, transaction, "SFin.TransactionSageSubmissionStatus_MarkSentLegacy",
                new[] { new SqlParameter("@UpdatedByUserID", SqlDbType.Int) { Value = -1 } },
                CommandType.StoredProcedure))
            {
                await command.ExecuteNonQueryAsync();
            }

            var statusCode = await SqlTestData.ReadTransactionSageSubmissionStatusCodeAsync(connection, transaction, statusId);
            Assert.Equal("Sent Legacy", statusCode);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task MarkSentLegacy_LeavesGenuinelyPendingRowUntouched()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var accountId = await SqlTestData.ReadActiveAccountIdAsync(connection, transaction);
            var fixture = await SqlTestData.InsertTransactionFixtureAsync(
                connection,
                transaction,
                accountId,
                reservedInvoiceNumber: "RES-P501-003");
            var statusId = await SqlTestData.InsertTransactionSageSubmissionStatusAsync(
                connection, transaction, fixture.TransactionId, fixture.TransactionGuid, "Pending");

            await using (var command = SqlTestDatabase.CreateCommand(
                connection, transaction, "SFin.TransactionSageSubmissionStatus_MarkSentLegacy",
                new[] { new SqlParameter("@UpdatedByUserID", SqlDbType.Int) { Value = -1 } },
                CommandType.StoredProcedure))
            {
                await command.ExecuteNonQueryAsync();
            }

            var statusCode = await SqlTestData.ReadTransactionSageSubmissionStatusCodeAsync(connection, transaction, statusId);
            Assert.Equal("Pending", statusCode);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }
}
