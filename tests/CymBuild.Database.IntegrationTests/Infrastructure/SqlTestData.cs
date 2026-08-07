using System.Data;

namespace CymBuild.Database.IntegrationTests.Infrastructure;

internal sealed record NonActivityFixture(
    Guid AbsenceTypeGuid,
    short TeamId,
    short MemberId,
    Guid CreatedByUserGuid,
    Guid FirstStatusGuid,
    Guid SecondStatusGuid);

internal static class SqlTestData
{
    internal static async Task<NonActivityFixture> ReadNonActivityFixtureAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
SELECT
    (SELECT TOP (1) nat.Guid
     FROM SCore.NonActivityTypes AS nat
     WHERE nat.RowStatus NOT IN (0, 254)
       AND nat.Guid IS NOT NULL
     ORDER BY nat.ID) AS AbsenceTypeGuid,
    (SELECT TOP (1) CONVERT(SMALLINT, g.ID)
     FROM SCore.Groups AS g
     WHERE g.RowStatus NOT IN (0, 254)
       AND TRY_CONVERT(SMALLINT, g.ID) IS NOT NULL
     ORDER BY CASE WHEN g.ID = -1 THEN 0 ELSE 1 END, g.ID) AS TeamId,
    (SELECT TOP (1) CONVERT(SMALLINT, i.ID)
     FROM SCore.Identities AS i
     WHERE i.RowStatus NOT IN (0, 254)
       AND TRY_CONVERT(SMALLINT, i.ID) IS NOT NULL
       AND i.Guid IS NOT NULL
     ORDER BY CASE WHEN i.ID = -1 THEN 0 ELSE 1 END, i.ID) AS MemberId,
    (SELECT TOP (1) i.Guid
     FROM SCore.Identities AS i
     WHERE i.RowStatus NOT IN (0, 254)
       AND i.Guid IS NOT NULL
     ORDER BY CASE WHEN i.ID = -1 THEN 0 ELSE 1 END, i.ID) AS CreatedByUserGuid;
""";

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        Assert.True(await reader.ReadAsync(cancellationToken), "The SQL fixture query did not return a row.");

        Assert.False(reader.IsDBNull(0), "No active SCore.NonActivityTypes row is available in the dedicated test database.");
        Assert.False(reader.IsDBNull(1), "No SCore.Groups ID compatible with the production SMALLINT procedure parameter is available.");
        Assert.False(reader.IsDBNull(2), "No SCore.Identities ID compatible with the production SMALLINT procedure parameter is available.");
        Assert.False(reader.IsDBNull(3), "No active identity GUID is available for workflow transition tests.");

        var absenceTypeGuid = reader.GetGuid(0);
        var teamId = reader.GetInt16(1);
        var memberId = reader.GetInt16(2);
        var createdByUserGuid = reader.GetGuid(3);
        await reader.DisposeAsync();

        const string statusSql = """
SELECT TOP (2) ws.Guid
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus NOT IN (0, 254)
  AND ws.Guid IS NOT NULL
  AND ws.Guid <> '00000000-0000-0000-0000-000000000000'
ORDER BY ws.ID;
""";

        var statuses = new List<Guid>(capacity: 2);
        await using var statusCommand = SqlTestDatabase.CreateCommand(connection, transaction, statusSql);
        await using var statusReader = await statusCommand.ExecuteReaderAsync(cancellationToken);
        while (await statusReader.ReadAsync(cancellationToken))
        {
            statuses.Add(statusReader.GetGuid(0));
        }

        Assert.True(statuses.Count >= 2, "At least two active workflow statuses are required in the dedicated test database.");

        return new NonActivityFixture(
            absenceTypeGuid,
            teamId,
            memberId,
            createdByUserGuid,
            statuses[0],
            statuses[1]);
    }

    internal static async Task ExecuteNonActivityEventUpsertAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        NonActivityFixture fixture,
        Guid recordGuid,
        DateTime startTime,
        DateTime endTime,
        CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@AbsenceTypeGuid", SqlDbType.UniqueIdentifier) { Value = fixture.AbsenceTypeGuid },
            new SqlParameter("@StartTime", SqlDbType.DateTime) { Value = startTime },
            new SqlParameter("@EndTime", SqlDbType.DateTime) { Value = endTime },
            new SqlParameter("@TeamId", SqlDbType.SmallInt) { Value = fixture.TeamId },
            new SqlParameter("@MemberId", SqlDbType.SmallInt) { Value = fixture.MemberId },
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = recordGuid }
        };

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SCore.NonActivityEventsUpsert",
            parameters,
            CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    internal static async Task ExecuteTransitionUpsertAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid transitionGuid,
        Guid oldStatusGuid,
        Guid statusGuid,
        string comment,
        Guid createdByUserGuid,
        Guid dataObjectGuid,
        CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = transitionGuid },
            new SqlParameter("@OldStatusGuid", SqlDbType.UniqueIdentifier) { Value = oldStatusGuid },
            new SqlParameter("@StatusGuid", SqlDbType.UniqueIdentifier) { Value = statusGuid },
            new SqlParameter("@Comment", SqlDbType.NVarChar, -1) { Value = comment },
            new SqlParameter("@CreatedByUserGuid", SqlDbType.UniqueIdentifier) { Value = createdByUserGuid },
            new SqlParameter("@SurveyorUserGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Empty },
            new SqlParameter("@DataObjectGuid", SqlDbType.UniqueIdentifier) { Value = dataObjectGuid },
            new SqlParameter("@IsImported", SqlDbType.Bit) { Value = false }
        };

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SCore.DataObjectTransitionUpsert",
            parameters,
            CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
