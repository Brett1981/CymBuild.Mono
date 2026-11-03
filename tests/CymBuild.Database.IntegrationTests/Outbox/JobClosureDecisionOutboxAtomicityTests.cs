using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Outbox;

public sealed class JobClosureDecisionOutboxAtomicityTests
{
    private static readonly Guid AuthoriserIdentityGuid = Guid.Parse("D4D00004-0000-4000-8000-000000000001");

    [Fact]
    public async Task ApproveDecision_WritesTransitionsAndOutboxEventTogether()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await SqlTestData.ReadJobClosureFixtureAsync(connection, transaction);
            var jobGuid = Guid.NewGuid();

            await SqlTestData.InsertJobFixtureAsync(connection, transaction, jobGuid, fixture, "R4-JOB-0001");
            await SqlTestData.ExecuteTransitionUpsertAsync(
                connection,
                transaction,
                Guid.NewGuid(),
                Guid.Empty,
                fixture.ClosureRequestStatusGuid,
                "R4 moved to closure request",
                AuthoriserIdentityGuid,
                jobGuid);

            var result = await SqlTestData.ExecuteJobClosureDecisionAsync(
                connection,
                transaction,
                jobGuid,
                fixture.AuthoriserIdentityId,
                decision: 1,
                comment: null);

            Assert.Contains("Closure Approved by", result.StoredComment, StringComparison.Ordinal);

            var statuses = await ReadTransitionStatusesAsync(connection, transaction, jobGuid);
            Assert.Equal(
                new[] { fixture.ClosureRequestStatusGuid, fixture.ApproveClosureStatusGuid, fixture.CompletedStatusGuid },
                statuses);

            var outboxCount = await CountJobClosureOutboxRowsAsync(connection, transaction, jobGuid);
            Assert.Equal(1L, outboxCount);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    /// <summary>
    /// Runs outside an ambient test transaction on purpose: SJob.usp_JobClosureDecision's own
    /// ROLLBACK is a plain (non-savepoint) T-SQL ROLLBACK, which unwinds all the way to the
    /// session's outermost BEGIN TRAN. Wrapping the setup in the same outer transaction as the
    /// procedure call would make the procedure's failure also erase the pre-existing "Closure
    /// Request" transition created before the procedure ran, making it impossible to tell the
    /// procedure's own rollback apart from the test's own cleanup. Each statement here commits
    /// independently instead, and the finally block undoes them explicitly.
    /// </summary>
    [Fact]
    public async Task ApproveDecision_FailureDuringSecondTransition_RollsBackFirstTransitionAndOutbox()
    {
        var database = SqlTestDatabase.FromEnvironment();
        var fixture = await ReadFixtureAutoCommitAsync(database);
        var jobGuid = Guid.NewGuid();

        await using (var connection = await database.OpenConnectionAsync())
        {
            await SqlTestData.InsertJobFixtureAsync(connection, transaction: null, jobGuid, fixture, "R4-JOB-0002");
            await SqlTestData.ExecuteTransitionUpsertAsync(
                connection,
                transaction: null,
                Guid.NewGuid(),
                Guid.Empty,
                fixture.ClosureRequestStatusGuid,
                "R4 moved to closure request",
                AuthoriserIdentityGuid,
                jobGuid);
        }

        await database.ExecuteNonQueryAsync(
            "UPDATE SCore.WorkflowStatus SET RowStatus = 254 WHERE Guid = @Guid;",
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = fixture.CompletedStatusGuid } });

        try
        {
            await using var connection = await database.OpenConnectionAsync();

            var exception = await Assert.ThrowsAsync<SqlException>(() =>
                SqlTestData.ExecuteJobClosureDecisionAsync(
                    connection,
                    transaction: null,
                    jobGuid,
                    fixture.AuthoriserIdentityId,
                    decision: 1,
                    comment: null));
            Assert.Equal(61099, exception.Number);

            var statuses = await ReadTransitionStatusesAsync(connection, transaction: null, jobGuid);
            Assert.Equal(new[] { fixture.ClosureRequestStatusGuid }, statuses);

            var outboxCount = await CountJobClosureOutboxRowsAsync(connection, transaction: null, jobGuid);
            Assert.Equal(0L, outboxCount);
        }
        finally
        {
            await database.ExecuteNonQueryAsync(
                "UPDATE SCore.WorkflowStatus SET RowStatus = 1 WHERE Guid = @Guid;",
                new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = fixture.CompletedStatusGuid } });
            await database.ExecuteNonQueryAsync(
                "DELETE FROM SCore.IntegrationOutbox WHERE TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(PayloadJson, '$.jobGuid')) = @JobGuid;",
                new[] { new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid } });
            await database.ExecuteNonQueryAsync(
                "DELETE FROM SCore.DataObjectTransition WHERE DataObjectGuid = @JobGuid;",
                new[] { new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid } });
            await database.ExecuteNonQueryAsync(
                "DELETE FROM SJob.Jobs WHERE Guid = @JobGuid;",
                new[] { new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid } });
            await database.ExecuteNonQueryAsync(
                "DELETE FROM SCore.DataObjects WHERE Guid = @JobGuid;",
                new[] { new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid } });
        }
    }

    private static async Task<SqlTestData.JobClosureFixture> ReadFixtureAutoCommitAsync(SqlTestDatabase database)
    {
        await using var connection = await database.OpenConnectionAsync();
        return await SqlTestData.ReadJobClosureFixtureAsync(connection, transaction: null);
    }

    private static async Task<Guid[]> ReadTransitionStatusesAsync(
        SqlConnection connection, SqlTransaction? transaction, Guid jobGuid)
    {
        const string sql = """
SELECT ws.Guid
FROM SCore.DataObjectTransition AS dot
JOIN SCore.WorkflowStatus AS ws ON ws.ID = dot.StatusID
WHERE dot.DataObjectGuid = @JobGuid
  AND dot.RowStatus NOT IN (0, 254)
ORDER BY dot.ID;
""";
        var statuses = new List<Guid>();
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[] { new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid } });
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            statuses.Add(reader.GetGuid(0));
        }

        return statuses.ToArray();
    }

    private static async Task<long> CountJobClosureOutboxRowsAsync(
        SqlConnection connection, SqlTransaction? transaction, Guid jobGuid)
    {
        const string sql = """
SELECT COUNT_BIG(1)
FROM SCore.IntegrationOutbox
WHERE EventType = N'JobClosureDecision'
  AND RowStatus NOT IN (0, 254)
  AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(PayloadJson, '$.jobGuid')) = @JobGuid;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[] { new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid } });
        return (long)(await command.ExecuteScalarAsync() ?? 0L);
    }
}
