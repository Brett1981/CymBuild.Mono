using CymBuild.Database.IntegrationTests.Infrastructure;

namespace CymBuild.Database.IntegrationTests.Workflow;

public sealed class AuthorisationQueueCountsRegressionTests
{
    // Regression guard for the AUTHOREVIEW grid performance work: Concursus.EF.Core.GetAuthorisationQueueCountsAsync
    // queries SCore.tvf_WF_AuthorisationQueue directly to skip SCore.vw_WF_AuthorisationQueue_Display's
    // Job/Quote/Enquiry joins and its two SJob.Job_FeeDrawdown evaluations, which the KPI badge counts
    // never use. This must keep returning the same per-entity-type pending counts as the full display view.
    [Fact]
    public async Task LeanCountQueryMatchesDisplayViewCountsPerEntityType()
    {
        var database = SqlTestDatabase.FromEnvironment();

        const string leanSql = """
SELECT
    et.Name AS EntityTypeName,
    COUNT(*) AS PendingCount
FROM SCore.tvf_WF_AuthorisationQueue(NULL, -1) q
JOIN SCore.EntityTypes et
    ON et.ID = q.EntityTypeId
   AND et.RowStatus NOT IN (0,254)
GROUP BY et.Name;
""";

        const string displayViewSql = """
SELECT
    v.EntityTypeName,
    COUNT(*) AS PendingCount
FROM SCore.vw_WF_AuthorisationQueue_Display v
GROUP BY v.EntityTypeName;
""";

        var lean = await ReadCountsByEntityTypeAsync(database, leanSql);
        var display = await ReadCountsByEntityTypeAsync(database, displayViewSql);

        Assert.Equal(display, lean);
    }

    private static async Task<Dictionary<string, int>> ReadCountsByEntityTypeAsync(SqlTestDatabase database, string sql)
    {
        var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

        await using var connection = await database.OpenConnectionAsync();
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction: null, sql);
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            counts[reader.GetString(0)] = reader.GetInt32(1);
        }

        return counts;
    }
}
