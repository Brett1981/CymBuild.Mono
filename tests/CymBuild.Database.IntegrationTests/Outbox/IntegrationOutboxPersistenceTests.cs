using Concursus.API.Services.Outbox;
using CymBuild.Database.IntegrationTests.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using System.Data;
using System.Text.Json;

namespace CymBuild.Database.IntegrationTests.Outbox;

public sealed class IntegrationOutboxPersistenceTests
{
    [Fact]
    public async Task ClaimAssignsLeaseAndIncrementsAttempts()
    {
        var database = SqlTestDatabase.FromEnvironment();
        var row = await InsertOutboxAsync(database, rowStatus: 1, createdOnUtc: new DateTime(1900, 1, 1));

        try
        {
            var repository = CreateRepository(database);
            var claimed = await repository.ClaimBatchAsync(1, 5, CancellationToken.None);
            var item = Assert.Single(claimed.Where(candidate => candidate.OutboxGuid == row.Guid));

            Assert.Equal(1, item.PublishAttempts);
            Assert.NotEqual(Guid.Empty, item.PublishingToken);

            var persisted = await ReadOutboxAsync(database, row.Guid);
            Assert.Equal(item.PublishingToken, persisted.PublishingToken);
            Assert.Equal(1, persisted.PublishAttempts);
            Assert.NotNull(persisted.PublishingStartedOnUtc);
        }
        finally
        {
            await DeleteOutboxAsync(database, row.Guid);
        }
    }

    [Fact]
    public async Task ConcurrentClaimsDoNotReturnSameRows()
    {
        var database = SqlTestDatabase.FromEnvironment();
        var first = await InsertOutboxAsync(database, 1, new DateTime(1899, 1, 1));
        var second = await InsertOutboxAsync(database, 1, new DateTime(1899, 1, 2));

        try
        {
            var repositoryOne = CreateRepository(database);
            var repositoryTwo = CreateRepository(database);

            var claims = await Task.WhenAll(
                repositoryOne.ClaimBatchAsync(1, 5, CancellationToken.None),
                repositoryTwo.ClaimBatchAsync(1, 5, CancellationToken.None));

            var testGuids = new HashSet<Guid> { first.Guid, second.Guid };
            var claimedTestGuids = claims
                .SelectMany(batch => batch)
                .Where(item => testGuids.Contains(item.OutboxGuid))
                .Select(item => item.OutboxGuid)
                .ToArray();

            Assert.Equal(2, claimedTestGuids.Length);
            Assert.Equal(2, claimedTestGuids.Distinct().Count());
        }
        finally
        {
            await DeleteOutboxAsync(database, first.Guid, second.Guid);
        }
    }

    [Theory]
    [InlineData(0)]
    [InlineData(254)]
    public async Task InactiveRowsAreNotClaimed(byte rowStatus)
    {
        var database = SqlTestDatabase.FromEnvironment();
        var inactive = await InsertOutboxAsync(database, rowStatus, new DateTime(1898, 1, 1));
        var active = await InsertOutboxAsync(database, 1, new DateTime(1898, 1, 2));

        try
        {
            var repository = CreateRepository(database);
            var claimed = await repository.ClaimBatchAsync(1, 5, CancellationToken.None);

            Assert.DoesNotContain(claimed, item => item.OutboxGuid == inactive.Guid);
            Assert.Contains(claimed, item => item.OutboxGuid == active.Guid);

            var persistedInactive = await ReadOutboxAsync(database, inactive.Guid);
            Assert.Equal(0, persistedInactive.PublishAttempts);
            Assert.Null(persistedInactive.PublishingToken);
        }
        finally
        {
            await DeleteOutboxAsync(database, inactive.Guid, active.Guid);
        }
    }

    [Fact]
    public async Task MarkPublishedRequiresMatchingLeaseToken()
    {
        var database = SqlTestDatabase.FromEnvironment();
        var leaseToken = Guid.NewGuid();
        var row = await InsertOutboxAsync(
            database,
            rowStatus: 1,
            createdOnUtc: new DateTime(1901, 1, 1),
            publishingToken: leaseToken,
            publishingStartedOnUtc: DateTime.UtcNow);

        try
        {
            var repository = CreateRepository(database);
            await repository.MarkPublishedAsync(row.Id, Guid.NewGuid(), CancellationToken.None);
            var afterWrongToken = await ReadOutboxAsync(database, row.Guid);
            Assert.Null(afterWrongToken.PublishedOnUtc);
            Assert.Equal(leaseToken, afterWrongToken.PublishingToken);

            await repository.MarkPublishedAsync(row.Id, leaseToken, CancellationToken.None);
            var afterCorrectToken = await ReadOutboxAsync(database, row.Guid);
            Assert.NotNull(afterCorrectToken.PublishedOnUtc);
            Assert.Null(afterCorrectToken.PublishingToken);
            Assert.Null(afterCorrectToken.PublishingStartedOnUtc);
            Assert.Null(afterCorrectToken.LastError);
        }
        finally
        {
            await DeleteOutboxAsync(database, row.Guid);
        }
    }

    [Fact]
    public async Task MarkFailedTruncatesErrorAndReleasesLease()
    {
        var database = SqlTestDatabase.FromEnvironment();
        var leaseToken = Guid.NewGuid();
        var row = await InsertOutboxAsync(
            database,
            rowStatus: 1,
            createdOnUtc: new DateTime(1902, 1, 1),
            publishingToken: leaseToken,
            publishingStartedOnUtc: DateTime.UtcNow);

        try
        {
            var repository = CreateRepository(database);
            await repository.MarkFailedAsync(row.Id, leaseToken, new string('x', 2500), CancellationToken.None);

            var persisted = await ReadOutboxAsync(database, row.Guid);
            Assert.Null(persisted.PublishingToken);
            Assert.Null(persisted.PublishingStartedOnUtc);
            Assert.NotNull(persisted.LastError);
            Assert.Equal(2000, persisted.LastError!.Length);
        }
        finally
        {
            await DeleteOutboxAsync(database, row.Guid);
        }
    }

    [Fact]
    public async Task ExpiredLeaseCanBeReclaimed()
    {
        var database = SqlTestDatabase.FromEnvironment();
        var originalToken = Guid.NewGuid();
        var row = await InsertOutboxAsync(
            database,
            rowStatus: 1,
            createdOnUtc: new DateTime(1903, 1, 1),
            publishingToken: originalToken,
            publishingStartedOnUtc: DateTime.UtcNow.AddMinutes(-20));

        try
        {
            var repository = CreateRepository(database);
            var claimed = await repository.ClaimBatchAsync(1, 5, CancellationToken.None);
            var item = Assert.Single(claimed.Where(candidate => candidate.OutboxGuid == row.Guid));

            Assert.NotEqual(originalToken, item.PublishingToken);
            Assert.Equal(1, item.PublishAttempts);
        }
        finally
        {
            await DeleteOutboxAsync(database, row.Guid);
        }
    }

    private static WorkflowOutboxRepository CreateRepository(SqlTestDatabase database)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:ShoreDB"] = database.ConnectionString
            })
            .Build();

        return new WorkflowOutboxRepository(
            configuration,
            NullLogger<WorkflowOutboxRepository>.Instance);
    }

    private static async Task<OutboxSeed> InsertOutboxAsync(
        SqlTestDatabase database,
        byte rowStatus,
        DateTime createdOnUtc,
        Guid? publishingToken = null,
        DateTime? publishingStartedOnUtc = null)
    {
        var guid = Guid.NewGuid();
        var payload = JsonSerializer.Serialize(new { jobGuid = Guid.NewGuid(), source = "R4" });
        const string sql = """
INSERT INTO SCore.IntegrationOutbox
(
    RowStatus,
    Guid,
    CreatedOnUtc,
    EventType,
    PayloadJson,
    PublishedOnUtc,
    PublishAttempts,
    LastError,
    PublishingToken,
    PublishingStartedOnUtc
)
OUTPUT inserted.ID
VALUES
(
    @RowStatus,
    @Guid,
    @CreatedOnUtc,
    N'JobClosureDecision',
    @PayloadJson,
    NULL,
    0,
    NULL,
    @PublishingToken,
    @PublishingStartedOnUtc
);
""";

        await using var connection = await database.OpenConnectionAsync();
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction: null,
            sql,
            new[]
            {
                new SqlParameter("@RowStatus", SqlDbType.TinyInt) { Value = rowStatus },
                new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = guid },
                new SqlParameter("@CreatedOnUtc", SqlDbType.DateTime2) { Value = createdOnUtc },
                new SqlParameter("@PayloadJson", SqlDbType.NVarChar, -1) { Value = payload },
                new SqlParameter("@PublishingToken", SqlDbType.UniqueIdentifier) { Value = (object?)publishingToken ?? DBNull.Value },
                new SqlParameter("@PublishingStartedOnUtc", SqlDbType.DateTime2) { Value = (object?)publishingStartedOnUtc ?? DBNull.Value }
            });
        var id = Convert.ToInt64(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
        return new OutboxSeed(id, guid);
    }

    private static async Task<OutboxState> ReadOutboxAsync(SqlTestDatabase database, Guid guid)
    {
        const string sql = """
SELECT PublishAttempts, PublishingToken, PublishingStartedOnUtc, PublishedOnUtc, LastError
FROM SCore.IntegrationOutbox
WHERE Guid = @Guid;
""";

        await using var connection = await database.OpenConnectionAsync();
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction: null,
            sql,
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = guid } });
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());

        return new OutboxState(
            reader.GetInt32(0),
            reader.IsDBNull(1) ? null : reader.GetGuid(1),
            reader.IsDBNull(2) ? null : reader.GetDateTime(2),
            reader.IsDBNull(3) ? null : reader.GetDateTime(3),
            reader.IsDBNull(4) ? null : reader.GetString(4));
    }

    private static async Task DeleteOutboxAsync(SqlTestDatabase database, params Guid[] guids)
    {
        if (guids.Length == 0)
        {
            return;
        }

        var parameterNames = new List<string>(guids.Length);
        var parameters = new List<SqlParameter>(guids.Length);
        for (var index = 0; index < guids.Length; index++)
        {
            var parameterName = $"@Guid{index}";
            parameterNames.Add(parameterName);
            parameters.Add(new SqlParameter(parameterName, SqlDbType.UniqueIdentifier) { Value = guids[index] });
        }

        await database.ExecuteNonQueryAsync(
            $"DELETE FROM SCore.IntegrationOutbox WHERE Guid IN ({string.Join(", ", parameterNames)});",
            parameters);
    }

    private sealed record OutboxSeed(long Id, Guid Guid);

    private sealed record OutboxState(
        int PublishAttempts,
        Guid? PublishingToken,
        DateTime? PublishingStartedOnUtc,
        DateTime? PublishedOnUtc,
        string? LastError);
}
