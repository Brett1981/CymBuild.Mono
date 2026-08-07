using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.DataObjects;

public sealed class DataObjectInvariantTests
{
    [Fact]
    public async Task EntityUpsertCreatesMatchingDataObjectWithEntityType()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await SqlTestData.ReadNonActivityFixtureAsync(connection, transaction);
            var recordGuid = Guid.NewGuid();
            var startTime = new DateTime(2030, 1, 2, 9, 0, 0, DateTimeKind.Unspecified);

            await SqlTestData.ExecuteNonActivityEventUpsertAsync(
                connection,
                transaction,
                fixture,
                recordGuid,
                startTime,
                startTime.AddHours(1));

            const string sql = """
SELECT
    e.Guid,
    e.RowStatus,
    DATALENGTH(e.RowVersion),
    d.RowStatus,
    DATALENGTH(d.RowVersion),
    d.EntityTypeId,
    eh.EntityTypeID
FROM SCore.NonActivityEvents AS e
JOIN SCore.DataObjects AS d ON d.Guid = e.Guid
JOIN SCore.EntityHobts AS eh
  ON eh.SchemaName = N'SCore'
 AND eh.ObjectName = N'NonActivityEvents'
WHERE e.Guid = @Guid;
""";

            await using var command = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                sql,
                new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = recordGuid } });
            await using var reader = await command.ExecuteReaderAsync();

            Assert.True(await reader.ReadAsync());
            Assert.Equal(recordGuid, reader.GetGuid(0));
            Assert.Equal((byte)1, reader.GetByte(1));
            Assert.Equal(8, reader.GetInt32(2));
            Assert.Equal((byte)1, reader.GetByte(3));
            Assert.Equal(8, reader.GetInt32(4));
            Assert.Equal(reader.GetInt32(6), reader.GetInt32(5));
            Assert.False(await reader.ReadAsync());
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task RepeatedEntityUpsertIsIdempotentAndUpdatesExistingRow()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await SqlTestData.ReadNonActivityFixtureAsync(connection, transaction);
            var recordGuid = Guid.NewGuid();
            var firstStart = new DateTime(2030, 2, 3, 10, 0, 0, DateTimeKind.Unspecified);
            var secondStart = firstStart.AddDays(1);

            await SqlTestData.ExecuteNonActivityEventUpsertAsync(
                connection, transaction, fixture, recordGuid, firstStart, firstStart.AddHours(1));
            await SqlTestData.ExecuteNonActivityEventUpsertAsync(
                connection, transaction, fixture, recordGuid, secondStart, secondStart.AddHours(2));

            const string sql = """
SELECT
    (SELECT COUNT_BIG(1) FROM SCore.NonActivityEvents WHERE Guid = @Guid),
    (SELECT COUNT_BIG(1) FROM SCore.DataObjects WHERE Guid = @Guid),
    (SELECT StartTime FROM SCore.NonActivityEvents WHERE Guid = @Guid);
""";

            await using var command = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                sql,
                new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = recordGuid } });
            await using var reader = await command.ExecuteReaderAsync();

            Assert.True(await reader.ReadAsync());
            Assert.Equal(1L, reader.GetInt64(0));
            Assert.Equal(1L, reader.GetInt64(1));
            Assert.Equal(secondStart, reader.GetDateTime(2));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task CallerTransactionRollbackRemovesEntityAndDataObject()
    {
        var database = SqlTestDatabase.FromEnvironment();
        var recordGuid = Guid.NewGuid();

        await using (var connection = await database.OpenConnectionAsync())
        await using (var transaction = (SqlTransaction)await connection.BeginTransactionAsync())
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await SqlTestData.ReadNonActivityFixtureAsync(connection, transaction);
            var startTime = new DateTime(2030, 3, 4, 11, 0, 0, DateTimeKind.Unspecified);

            await SqlTestData.ExecuteNonActivityEventUpsertAsync(
                connection, transaction, fixture, recordGuid, startTime, startTime.AddHours(1));
            await transaction.RollbackAsync();
        }

        const string sql = """
SELECT
    (SELECT COUNT_BIG(1) FROM SCore.NonActivityEvents WHERE Guid = @Guid)
  + (SELECT COUNT_BIG(1) FROM SCore.DataObjects WHERE Guid = @Guid);
""";

        var remaining = await database.ExecuteScalarAsync<long>(
            sql,
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = recordGuid } });
        Assert.Equal(0L, remaining);
    }

    [Fact]
    public async Task UpsertDataObjectRejectsDataObjectWithoutEntityRow()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var entityTypeIdSql = """
SELECT TOP (1) eh.EntityTypeID
FROM SCore.EntityHobts AS eh
WHERE eh.SchemaName = N'SCore'
  AND eh.ObjectName = N'NonActivityEvents';
""";
            await using var entityTypeCommand = SqlTestDatabase.CreateCommand(connection, transaction, entityTypeIdSql);
            var entityTypeId = Convert.ToInt32(await entityTypeCommand.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
            var recordGuid = Guid.NewGuid();

            const string insertDataObjectSql = """
INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
VALUES (@Guid, 1, @EntityTypeId);
""";
            await using (var insertCommand = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                insertDataObjectSql,
                new[]
                {
                    new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = recordGuid },
                    new SqlParameter("@EntityTypeId", SqlDbType.Int) { Value = entityTypeId }
                }))
            {
                await insertCommand.ExecuteNonQueryAsync();
            }

            var isInsertParameter = new SqlParameter("@IsInsert", SqlDbType.Bit)
            {
                Direction = ParameterDirection.Output
            };
            await using var command = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                "SCore.UpsertDataObject",
                new[]
                {
                    new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = recordGuid },
                    new SqlParameter("@SchemeName", SqlDbType.NVarChar, 255) { Value = "SCore" },
                    new SqlParameter("@ObjectName", SqlDbType.NVarChar, 255) { Value = "NonActivityEvents" },
                    new SqlParameter("@IncludeDefaultSecurity", SqlDbType.Bit) { Value = false },
                    isInsertParameter
                },
                CommandType.StoredProcedure);

            var exception = await Assert.ThrowsAsync<SqlException>(() => command.ExecuteNonQueryAsync());
            Assert.Equal(60000, exception.Number);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }
}
