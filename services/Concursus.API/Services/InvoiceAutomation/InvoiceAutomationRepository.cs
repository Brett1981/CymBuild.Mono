using Microsoft.Data.SqlClient;
using System.Data;

namespace Concursus.API.Services.InvoiceAutomation;

public sealed class InvoiceAutomationRepository
{
    private readonly string _connectionString;
    private readonly ILogger<InvoiceAutomationRepository> _logger;

    public InvoiceAutomationRepository(
        IConfiguration configuration,
        ILogger<InvoiceAutomationRepository> logger)
    {
        _connectionString = configuration.GetConnectionString("ShoreDB")
            ?? throw new InvalidOperationException("ConnectionStrings:ShoreDB is missing.");

        _logger = logger;
    }

    // ---------------------------------------------------------------------
    // PUBLIC API (unchanged)
    // ---------------------------------------------------------------------

    public async Task<(int inserted, int updated, int attempt)> MaterialiseTriggerInstancesAsync(
        DateTime? detectedUtc,
        int maxAttempts,
        CancellationToken ct)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        return await MaterialiseTriggerInstancesAsync(conn, detectedUtc, maxAttempts, ct);
    }

    public async Task RunPhase4To6Async(
        Guid runGuid,
        Guid requesterUserGuid,
        Guid? defaultPaymentStatusGuid,
        string? notes,
        DateTime? nowUtc,
        CancellationToken ct)
    {
        if (requesterUserGuid == Guid.Empty)
            throw new InvalidOperationException(
                "InvoiceAutomation:RequesterUserGuid must be set to a valid SCore.Identities.Guid.");

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        await RunPhase4To6Async(
            conn,
            runGuid,
            requesterUserGuid,
            defaultPaymentStatusGuid,
            notes,
            nowUtc,
            ct);
    }

    public async Task<int> DequeueNudgesAsync(int take, CancellationToken ct)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        return await DequeueNudgesAsync(conn, take, ct);
    }

    // ---------------------------------------------------------------------
    // OVERLOADS (existing connection required for applock scenario)
    // ---------------------------------------------------------------------

    public async Task<(int inserted, int updated, int attempt)> MaterialiseTriggerInstancesAsync(
        SqlConnection conn,
        DateTime? detectedUtc,
        int maxAttempts,
        CancellationToken ct)
    {
        EnsureOpen(conn);

        await using var cmd = new SqlCommand(
            "[SFin].[InvoiceScheduleTriggerInstances_Materialise]",
            conn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 0
        };

        cmd.Parameters.Add(new SqlParameter("@DetectedDateTimeUTC", SqlDbType.DateTime2)
        {
            Value = (object?)detectedUtc ?? DBNull.Value
        });

        cmd.Parameters.Add(new SqlParameter("@MaxAttempts", SqlDbType.Int)
        {
            Value = maxAttempts
        });

        await using var reader = await cmd.ExecuteReaderAsync(ct);

        if (!await reader.ReadAsync(ct))
            return (0, 0, 0);

        var inserted = reader.GetInt32(reader.GetOrdinal("InsertedCount"));
        var updated = reader.GetInt32(reader.GetOrdinal("UpdatedCount"));
        var attempt = reader.GetInt32(reader.GetOrdinal("Attempt"));

        return (inserted, updated, attempt);
    }

    public async Task RunPhase4To6Async(
        SqlConnection conn,
        Guid runGuid,
        Guid requesterUserGuid,
        Guid? defaultPaymentStatusGuid,
        string? notes,
        DateTime? nowUtc,
        CancellationToken ct)
    {
        EnsureOpen(conn);

        await using var cmd = new SqlCommand(
            "[SFin].[InvoiceAutomation_Run_Phase4To6]",
            conn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 0
        };

        cmd.Parameters.Add(new SqlParameter("@AutomationRunGuid", SqlDbType.UniqueIdentifier)
        {
            Value = runGuid
        });

        cmd.Parameters.Add(new SqlParameter("@RequesterUserGuid", SqlDbType.UniqueIdentifier)
        {
            Value = requesterUserGuid
        });

        cmd.Parameters.Add(new SqlParameter("@DefaultPaymentStatusGuid", SqlDbType.UniqueIdentifier)
        {
            Value = (object?)defaultPaymentStatusGuid ?? DBNull.Value
        });

        cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, -1)
        {
            Value = (object?)notes ?? DBNull.Value
        });

        cmd.Parameters.Add(new SqlParameter("@NowUtc", SqlDbType.DateTime2)
        {
            Value = (object?)nowUtc ?? DBNull.Value
        });

        _logger.LogInformation("Invoice automation run starting: {RunGuid}", runGuid);

        await cmd.ExecuteNonQueryAsync(ct);

        _logger.LogInformation("Invoice automation run completed: {RunGuid}", runGuid);
    }

    public async Task<int> DequeueNudgesAsync(
        SqlConnection conn,
        int take,
        CancellationToken ct)
    {
        EnsureOpen(conn);

        const string sql = @"
;WITH cte AS
(
    SELECT TOP (@Take) *
    FROM SFin.InvoiceAutomationNudgeQueue WITH (READPAST, UPDLOCK, ROWLOCK)
    WHERE ProcessedDateTimeUTC IS NULL
    ORDER BY CreatedDateTimeUTC
)
UPDATE cte
SET ProcessedDateTimeUTC = SYSUTCDATETIME(),
    ProcessAttempt = ProcessAttempt + 1
OUTPUT inserted.ID;
";

        await using var cmd = new SqlCommand(sql, conn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 0
        };

        cmd.Parameters.Add(new SqlParameter("@Take", SqlDbType.Int)
        {
            Value = take
        });

        var count = 0;

        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            count++;

        return count;
    }

    // ---------------------------------------------------------------------
    // NEW: STATUS / DIAGNOSTICS SUPPORT
    // ---------------------------------------------------------------------

    public async Task<InvoiceAutomationStatusDto> GetStatusAsync(
        InvoiceAutomationOptions opt,
        CancellationToken ct)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        Guid? lastRunGuid = null;
        DateTime? startedUtc = null;
        DateTime? completedUtc = null;
        string? notes = null;
        string? summary = null;

        const string lastRunSql = @"
SELECT TOP (1)
      Guid,
      StartedDateTimeUTC,
      CompletedDateTimeUTC,
      Notes
FROM SFin.InvoiceAutomationRuns
WHERE RowStatus NOT IN (0,254)
ORDER BY StartedDateTimeUTC DESC;";

        await using (var cmd = new SqlCommand(lastRunSql, conn))
        await using (var r = await cmd.ExecuteReaderAsync(ct))
        {
            if (await r.ReadAsync(ct))
            {
                lastRunGuid = r.GetGuid(0);
                startedUtc = r.IsDBNull(1) ? null : r.GetDateTime(1);
                completedUtc = r.IsDBNull(2) ? null : r.GetDateTime(2);
                notes = r.IsDBNull(3) ? null : r.GetString(3);
            }
        }

        if (lastRunGuid.HasValue)
        {
            const string summarySql = @"
SELECT TOP (1) Message
FROM SFin.InvoiceAutomationRunDetails
WHERE RowStatus NOT IN (0,254)
  AND AutomationRunGuid = @RunGuid
ORDER BY CreatedDateTimeUTC DESC;";

            await using var cmd = new SqlCommand(summarySql, conn);
            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier)
            {
                Value = lastRunGuid.Value
            });

            summary = (string?)await cmd.ExecuteScalarAsync(ct);
        }

        const string missingSql = @"
SELECT COUNT_BIG(1)
FROM SFin.InvoiceScheduleTriggerInstances ti
WHERE ti.RowStatus NOT IN (0,254)
  AND ti.CompletedDateTimeUTC IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM SFin.InvoiceRequests r
      WHERE r.RowStatus NOT IN (0,254)
        AND r.SourceType = N'TriggerInstance'
        AND r.SourceGuid = ti.Guid
  );";

        var missing =
            Convert.ToInt32(await new SqlCommand(missingSql, conn)
                .ExecuteScalarAsync(ct) ?? 0);

        return new InvoiceAutomationStatusDto
        {
            OptionsEnabled = opt.Enabled,
            IntervalSeconds = opt.IntervalSeconds,
            RequesterUserGuid = opt.RequesterUserGuid,
            SqlAppLockName = opt.SqlAppLockName,
            SqlAppLockTimeoutMs = opt.SqlAppLockTimeoutMs,

            LastRunGuid = lastRunGuid,
            LastRunStartedUtc = startedUtc,
            LastRunCompletedUtc = completedUtc,
            LastRunNotes = notes,
            LastRunSummary = summary,
            CompletedTriggerInstancesMissingRequests = missing
        };
    }

    // ---------------------------------------------------------------------
    // APP LOCK WRAPPER (unchanged behaviour)
    // ---------------------------------------------------------------------

    public async Task WithExclusiveAppLockAsync(
        string lockName,
        int timeoutMs,
        Func<SqlConnection, SqlTransaction?, CancellationToken, Task> action,
        CancellationToken ct)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        SqlTransaction? tx = null;

        var acquired = await SqlDistributedAppLock.TryAcquireExclusiveAsync(
            conn,
            tx,
            lockName,
            timeoutMs,
            ct);

        if (!acquired)
        {
            _logger.LogInformation(
                "Invoice automation skipped (lock busy): {LockName}",
                lockName);
            return;
        }

        try
        {
            await action(conn, tx, ct);
        }
        finally
        {
            try
            {
                await SqlDistributedAppLock.ReleaseAsync(conn, tx, lockName, ct);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "Failed to release app lock: {LockName}",
                    lockName);
            }
        }
    }

    // ---------------------------------------------------------------------
    // INTERNAL SAFETY
    // ---------------------------------------------------------------------

    private static void EnsureOpen(SqlConnection conn)
    {
        if (conn.State != ConnectionState.Open)
            throw new InvalidOperationException("Connection must be open.");
    }

    public async Task<(int insertedCount, int monthsCount)> GenerateMonthlyMonthConfigurationsAsync(
    Guid invoiceScheduleGuid,
    DateOnly startDate,
    DateOnly endDate,
    decimal totalValueNet,
    bool overwriteExisting,
    CancellationToken ct)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        return await GenerateMonthlyMonthConfigurationsAsync(
            conn, invoiceScheduleGuid, startDate, endDate, totalValueNet, overwriteExisting, ct);
    }

    public async Task<(int insertedCount, int monthsCount)> GenerateMonthlyMonthConfigurationsAsync(
        SqlConnection conn,
        Guid invoiceScheduleGuid,
        DateOnly startDate,
        DateOnly endDate,
        decimal totalValueNet,
        bool overwriteExisting,
        CancellationToken ct)
    {
        if (conn.State != ConnectionState.Open)
            throw new InvalidOperationException("Connection must be open.");

        await using var cmd = new SqlCommand(
            "[SFin].[InvoiceScheduleMonthConfiguration_GenerateMonthlySeries]",
            conn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 0
        };

        cmd.Parameters.Add(new SqlParameter("@InvoiceScheduleGuid", SqlDbType.UniqueIdentifier) { Value = invoiceScheduleGuid });
        cmd.Parameters.Add(new SqlParameter("@StartDate", SqlDbType.Date) { Value = startDate.ToDateTime(TimeOnly.MinValue) });
        cmd.Parameters.Add(new SqlParameter("@EndDate", SqlDbType.Date) { Value = endDate.ToDateTime(TimeOnly.MinValue) });
        cmd.Parameters.Add(new SqlParameter("@TotalValueNet", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = totalValueNet });
        cmd.Parameters.Add(new SqlParameter("@OverwriteExisting", SqlDbType.Bit) { Value = overwriteExisting });

        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct))
            return (0, 0);

        var inserted = r.GetInt32(r.GetOrdinal("InsertedCount"));
        var months = r.GetInt32(r.GetOrdinal("MonthsCount"));

        return (inserted, months);
    }
}