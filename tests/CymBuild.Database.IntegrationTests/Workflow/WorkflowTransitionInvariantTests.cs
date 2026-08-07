using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Workflow;

public sealed class WorkflowTransitionInvariantTests
{
    [Fact]
    public async Task TransitionUpsertCreatesTransitionAndMatchingDataObject()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await SqlTestData.ReadNonActivityFixtureAsync(connection, transaction);
            var recordGuid = Guid.NewGuid();
            var transitionGuid = Guid.NewGuid();
            var startTime = new DateTime(2030, 4, 5, 9, 0, 0, DateTimeKind.Unspecified);

            await SqlTestData.ExecuteNonActivityEventUpsertAsync(
                connection, transaction, fixture, recordGuid, startTime, startTime.AddHours(1));
            await SqlTestData.ExecuteTransitionUpsertAsync(
                connection,
                transaction,
                transitionGuid,
                Guid.Empty,
                fixture.FirstStatusGuid,
                "R4 transition",
                fixture.CreatedByUserGuid,
                recordGuid);

            const string sql = """
SELECT
    t.Guid,
    t.DataObjectGuid,
    d.EntityTypeId,
    eh.EntityTypeID,
    t.RowStatus,
    d.RowStatus
FROM SCore.DataObjectTransition AS t
JOIN SCore.DataObjects AS d ON d.Guid = t.Guid
JOIN SCore.EntityHobts AS eh
  ON eh.SchemaName = N'SCore'
 AND eh.ObjectName = N'DataObjectTransition'
WHERE t.Guid = @TransitionGuid;
""";

            await using var command = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                sql,
                new[] { new SqlParameter("@TransitionGuid", SqlDbType.UniqueIdentifier) { Value = transitionGuid } });
            await using var reader = await command.ExecuteReaderAsync();

            Assert.True(await reader.ReadAsync());
            Assert.Equal(transitionGuid, reader.GetGuid(0));
            Assert.Equal(recordGuid, reader.GetGuid(1));
            Assert.Equal(reader.GetInt32(3), reader.GetInt32(2));
            Assert.Equal((byte)1, reader.GetByte(4));
            Assert.Equal((byte)1, reader.GetByte(5));
            Assert.False(await reader.ReadAsync());
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task LatestActiveTransitionDefinesCurrentState()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await SqlTestData.ReadNonActivityFixtureAsync(connection, transaction);
            var recordGuid = Guid.NewGuid();
            var startTime = new DateTime(2030, 5, 6, 9, 0, 0, DateTimeKind.Unspecified);

            await SqlTestData.ExecuteNonActivityEventUpsertAsync(
                connection, transaction, fixture, recordGuid, startTime, startTime.AddHours(1));
            await SqlTestData.ExecuteTransitionUpsertAsync(
                connection, transaction, Guid.NewGuid(), Guid.Empty, fixture.FirstStatusGuid,
                "First", fixture.CreatedByUserGuid, recordGuid);
            await SqlTestData.ExecuteTransitionUpsertAsync(
                connection, transaction, Guid.NewGuid(), fixture.FirstStatusGuid, fixture.SecondStatusGuid,
                "Second", fixture.CreatedByUserGuid, recordGuid);

            const string sql = """
SELECT TOP (1) ws.Guid
FROM SCore.DataObjectTransition AS t
JOIN SCore.WorkflowStatus AS ws ON ws.ID = t.StatusID
WHERE t.DataObjectGuid = @RecordGuid
  AND t.RowStatus NOT IN (0, 254)
ORDER BY t.DateTimeUTC DESC, t.ID DESC;
""";

            await using var command = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                sql,
                new[] { new SqlParameter("@RecordGuid", SqlDbType.UniqueIdentifier) { Value = recordGuid } });
            var latestStatusGuid = (Guid)(await command.ExecuteScalarAsync() ?? Guid.Empty);
            Assert.Equal(fixture.SecondStatusGuid, latestStatusGuid);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task ReusingTransitionGuidUpdatesOneTransitionAndOneDataObject()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await SqlTestData.ReadNonActivityFixtureAsync(connection, transaction);
            var recordGuid = Guid.NewGuid();
            var transitionGuid = Guid.NewGuid();
            var startTime = new DateTime(2030, 6, 7, 9, 0, 0, DateTimeKind.Unspecified);

            await SqlTestData.ExecuteNonActivityEventUpsertAsync(
                connection, transaction, fixture, recordGuid, startTime, startTime.AddHours(1));
            await SqlTestData.ExecuteTransitionUpsertAsync(
                connection, transaction, transitionGuid, Guid.Empty, fixture.FirstStatusGuid,
                "Initial", fixture.CreatedByUserGuid, recordGuid);
            await SqlTestData.ExecuteTransitionUpsertAsync(
                connection, transaction, transitionGuid, fixture.FirstStatusGuid, fixture.SecondStatusGuid,
                "Updated", fixture.CreatedByUserGuid, recordGuid);

            const string sql = """
SELECT
    (SELECT COUNT_BIG(1) FROM SCore.DataObjectTransition WHERE Guid = @TransitionGuid),
    (SELECT COUNT_BIG(1) FROM SCore.DataObjects WHERE Guid = @TransitionGuid),
    (SELECT Comment FROM SCore.DataObjectTransition WHERE Guid = @TransitionGuid),
    (SELECT ws.Guid
     FROM SCore.DataObjectTransition AS t
     JOIN SCore.WorkflowStatus AS ws ON ws.ID = t.StatusID
     WHERE t.Guid = @TransitionGuid);
""";

            await using var command = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                sql,
                new[] { new SqlParameter("@TransitionGuid", SqlDbType.UniqueIdentifier) { Value = transitionGuid } });
            await using var reader = await command.ExecuteReaderAsync();

            Assert.True(await reader.ReadAsync());
            Assert.Equal(1L, reader.GetInt64(0));
            Assert.Equal(1L, reader.GetInt64(1));
            Assert.Equal("Updated", reader.GetString(2));
            Assert.Equal(fixture.SecondStatusGuid, reader.GetGuid(3));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task InvalidRecordGuidRollsBackTransitionDataObject()
    {
        var database = SqlTestDatabase.FromEnvironment();
        var transitionGuid = Guid.NewGuid();
        var missingRecordGuid = Guid.NewGuid();

        await using (var connection = await database.OpenConnectionAsync())
        {
            var fixture = await SqlTestData.ReadNonActivityFixtureAsync(connection, transaction: null);

            var exception = await Assert.ThrowsAsync<SqlException>(() =>
                SqlTestData.ExecuteTransitionUpsertAsync(
                    connection,
                    transaction: null,
                    transitionGuid,
                    Guid.Empty,
                    fixture.FirstStatusGuid,
                    "Missing record",
                    fixture.CreatedByUserGuid,
                    missingRecordGuid));
            Assert.Equal(61099, exception.Number);
            Assert.Contains("DataObjectGuid not found", exception.Message, StringComparison.Ordinal);
        }

        const string sql = """
SELECT
    (SELECT COUNT_BIG(1) FROM SCore.DataObjectTransition WHERE Guid = @TransitionGuid)
  + (SELECT COUNT_BIG(1) FROM SCore.DataObjects WHERE Guid = @TransitionGuid);
""";
        var remaining = await database.ExecuteScalarAsync<long>(
            sql,
            new[] { new SqlParameter("@TransitionGuid", SqlDbType.UniqueIdentifier) { Value = transitionGuid } });
        Assert.Equal(0L, remaining);
    }

    [Fact]
    public async Task WorkflowTransitionDoesNotChangeDataObjectRowStatus()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await SqlTestData.ReadNonActivityFixtureAsync(connection, transaction);
            var recordGuid = Guid.NewGuid();
            var startTime = new DateTime(2030, 7, 8, 9, 0, 0, DateTimeKind.Unspecified);

            await SqlTestData.ExecuteNonActivityEventUpsertAsync(
                connection, transaction, fixture, recordGuid, startTime, startTime.AddHours(1));

            await using var beforeCommand = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                "SELECT RowStatus FROM SCore.DataObjects WHERE Guid = @Guid;",
                new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = recordGuid } });
            var rowStatusBefore = Convert.ToByte(
                await beforeCommand.ExecuteScalarAsync(),
                System.Globalization.CultureInfo.InvariantCulture);

            await SqlTestData.ExecuteTransitionUpsertAsync(
                connection, transaction, Guid.NewGuid(), Guid.Empty, fixture.FirstStatusGuid,
                "State change", fixture.CreatedByUserGuid, recordGuid);

            await using var afterCommand = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                "SELECT RowStatus FROM SCore.DataObjects WHERE Guid = @Guid;",
                new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = recordGuid } });
            var rowStatusAfter = Convert.ToByte(
                await afterCommand.ExecuteScalarAsync(),
                System.Globalization.CultureInfo.InvariantCulture);

            Assert.Equal(rowStatusBefore, rowStatusAfter);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }
}
