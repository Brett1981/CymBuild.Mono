using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;
using System.Globalization;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-279: SFin.InvoiceScheduleMonthConfiguration_GenerateMonthlySeries pinned the final invoice
/// of every series to the End Date, so a Quarterly series from 01/11/2026 to 01/10/2027 produced
/// Nov, Feb, May, Oct (release/26.4 UI run on CymBuild_Dev264). Decision (2026-10-08): multi-month
/// frequencies keep their cadence and stop at the last cadence date on or before the End Date; the
/// Monthly series keeps its original "final invoice on the End Date" rule.
/// </summary>
public sealed class DrawdownSeriesCadenceTests
{
    public static TheoryData<string, string, string, decimal, string[], decimal[]> Cases => new()
    {
        // Quarterly: Nov, Feb, May, Aug - not Oct.
        { "Quarterly", "2026-11-01", "2027-10-01", 1200m, new[] { "2026-11-01", "2027-02-01", "2027-05-01", "2027-08-01" }, new[] { 300m, 300m, 300m, 300m } },
        // Quarterly where the next cadence date falls later in the End Date's month: dropped.
        { "Quarterly", "2026-11-15", "2027-08-01", 1200m, new[] { "2026-11-15", "2027-02-15", "2027-05-15" }, new[] { 400m, 400m, 400m } },
        // Bi-annual from a month end clamps short months and keeps the cadence.
        { "Bi-annual", "2026-01-31", "2027-01-31", 900m, new[] { "2026-01-31", "2026-07-31", "2027-01-31" }, new[] { 300m, 300m, 300m } },
        // Bi-monthly with a remainder on the last row.
        { "Bi-monthly", "2026-01-10", "2026-06-30", 100m, new[] { "2026-01-10", "2026-03-10", "2026-05-10" }, new[] { 33.33m, 33.33m, 33.34m } },
        // Monthly is unchanged: the final invoice is still pinned to the End Date.
        { "Monthly", "2026-11-01", "2027-01-15", 300m, new[] { "2026-11-01", "2026-12-01", "2027-01-15" }, new[] { 100m, 100m, 100m } },
    };

    [Theory]
    [MemberData(nameof(Cases))]
    public async Task GenerateSeries_FollowsTheFrequencyCadence(
        string frequency,
        string startDate,
        string endDate,
        decimal totalValueNet,
        string[] expectedDates,
        decimal[] expectedAmounts)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var scheduleGuid = await InsertScheduleAsync(connection, transaction);

            await GenerateAsync(connection, transaction, scheduleGuid, frequency, Date(startDate), Date(endDate), totalValueNet);

            var rows = await ReadRowsAsync(connection, transaction, scheduleGuid);
            Assert.Equal(expectedDates.Select(Date).ToArray(), rows.Select(r => r.Date).ToArray());
            Assert.Equal(expectedAmounts, rows.Select(r => r.Amount).ToArray());
            Assert.Equal(totalValueNet, rows.Sum(r => r.Amount));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    private static DateTime Date(string value) => DateTime.ParseExact(value, "yyyy-MM-dd", CultureInfo.InvariantCulture);

    private static async Task<Guid> InsertScheduleAsync(SqlConnection connection, SqlTransaction transaction)
    {
        var scheduleGuid = Guid.NewGuid();

        // The procedure registers each row's DataObject with EntityTypeId 201 (Invoice Schedule Month
        // Configuration) and SCore.DataObjects enforces FK_DataObjects_EntityTypes.
        const string sql = """
IF NOT EXISTS (SELECT 1 FROM SCore.EntityTypes WHERE ID = 201)
BEGIN
    SET IDENTITY_INSERT SCore.EntityTypes ON;
    INSERT INTO SCore.EntityTypes (ID, RowStatus, Guid, Name, IsReadOnlyOffline, IsRequiredSystemData, HasDocuments, LanguageLabelID, DoNotTrackChanges, IsRootEntity, DetailPageUrl, IconId, IsMetaData, IsDeletable, IsOnBoarding)
    VALUES (201, 1, '25855D38-D113-48B6-8F56-65959C49FC55', N'Invoice Schedule Month Configuration', 0, 1, 0, -1, 1, 0, N'', -1, 1, 0, 0);
    SET IDENTITY_INSERT SCore.EntityTypes OFF;
END;

INSERT INTO SFin.InvoiceSchedules (RowStatus, Guid) VALUES (1, @ScheduleGuid);
""";

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[] { new SqlParameter("@ScheduleGuid", SqlDbType.UniqueIdentifier) { Value = scheduleGuid } });
        await command.ExecuteNonQueryAsync();
        return scheduleGuid;
    }

    private static async Task GenerateAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid scheduleGuid,
        string frequency,
        DateTime startDate,
        DateTime endDate,
        decimal totalValueNet)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            """
EXEC SFin.InvoiceScheduleMonthConfiguration_GenerateMonthlySeries
    @InvoiceScheduleGuid = @ScheduleGuid,
    @StartDate = @StartDate,
    @EndDate = @EndDate,
    @TotalValueNet = @TotalValueNet,
    @Frequency = @Frequency,
    @OverwriteExisting = 0;
""",
            new[]
            {
                new SqlParameter("@ScheduleGuid", SqlDbType.UniqueIdentifier) { Value = scheduleGuid },
                new SqlParameter("@StartDate", SqlDbType.Date) { Value = startDate },
                new SqlParameter("@EndDate", SqlDbType.Date) { Value = endDate },
                new SqlParameter("@TotalValueNet", SqlDbType.Decimal) { Value = totalValueNet, Precision = 19, Scale = 2 },
                new SqlParameter("@Frequency", SqlDbType.VarChar, 20) { Value = frequency }
            });
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
        }
    }

    private static async Task<List<(DateTime Date, decimal Amount)>> ReadRowsAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid scheduleGuid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            """
SELECT mc.OnDayOfMonth, mc.Amount
FROM SFin.InvoiceScheduleMonthConfiguration AS mc
JOIN SFin.InvoiceSchedules AS s ON s.ID = mc.InvoiceScheduleId
WHERE s.Guid = @ScheduleGuid AND mc.RowStatus NOT IN (0, 254)
ORDER BY mc.PeriodNumber;
""",
            new[] { new SqlParameter("@ScheduleGuid", SqlDbType.UniqueIdentifier) { Value = scheduleGuid } });
        await using var reader = await command.ExecuteReaderAsync();
        var rows = new List<(DateTime, decimal)>();
        while (await reader.ReadAsync())
        {
            rows.Add((reader.GetDateTime(0), reader.GetDecimal(1)));
        }

        return rows;
    }
}
