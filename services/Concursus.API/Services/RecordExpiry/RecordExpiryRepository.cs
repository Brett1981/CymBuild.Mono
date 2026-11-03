using Microsoft.Data.SqlClient;
using System.Data;

namespace Concursus.API.Services.RecordExpiry;

public sealed record RecordExpiryFailure(string RecordType, Guid RecordGuid, string ErrorMessage);

public sealed record RecordExpiryRunResult(
    bool LockAcquired,
    int QuotesExpired,
    int EnquiriesExpired,
    int ExpiredSilently,
    IReadOnlyList<RecordExpiryFailure> Failures);

public interface IRecordExpiryRepository
{
    Task<RecordExpiryRunResult> ExpireOverdueAsync(
        Guid serviceUserGuid,
        int maxRecords,
        int notifyWithinDays,
        int commandTimeoutSeconds,
        CancellationToken ct);
}

/// <summary>
/// Runs SSop.ExpireOverdueQuotesAndEnquiries (CYB-461). The procedure owns the
/// expiry rules, the SCore.DataObjectTransitionUpsert write path and its own
/// application lock, so concurrent API replicas are safe.
/// </summary>
public sealed class RecordExpiryRepository : IRecordExpiryRepository
{
    private readonly string _connectionString;

    public RecordExpiryRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("ShoreDB")
            ?? throw new InvalidOperationException("ConnectionStrings:ShoreDB is missing.");
    }

    public async Task<RecordExpiryRunResult> ExpireOverdueAsync(
        Guid serviceUserGuid,
        int maxRecords,
        int notifyWithinDays,
        int commandTimeoutSeconds,
        CancellationToken ct)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        await using var cmd = new SqlCommand("[SSop].[ExpireOverdueQuotesAndEnquiries]", conn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = commandTimeoutSeconds
        };

        cmd.Parameters.Add(new SqlParameter("@ServiceUserGuid", SqlDbType.UniqueIdentifier) { Value = serviceUserGuid });
        cmd.Parameters.Add(new SqlParameter("@MaxRecords", SqlDbType.Int) { Value = maxRecords });
        cmd.Parameters.Add(new SqlParameter("@NotifyWithinDays", SqlDbType.Int) { Value = notifyWithinDays });

        await using var reader = await cmd.ExecuteReaderAsync(ct);

        if (!await reader.ReadAsync(ct))
            throw new InvalidOperationException("SSop.ExpireOverdueQuotesAndEnquiries returned no summary row.");

        var lockAcquired = reader.GetBoolean(reader.GetOrdinal("LockAcquired"));
        var quotesExpired = reader.GetInt32(reader.GetOrdinal("QuotesExpired"));
        var enquiriesExpired = reader.GetInt32(reader.GetOrdinal("EnquiriesExpired"));
        var expiredSilently = reader.GetInt32(reader.GetOrdinal("ExpiredSilently"));

        var failures = new List<RecordExpiryFailure>();

        if (await reader.NextResultAsync(ct))
        {
            while (await reader.ReadAsync(ct))
            {
                failures.Add(new RecordExpiryFailure(
                    reader.GetString(reader.GetOrdinal("RecordType")),
                    reader.GetGuid(reader.GetOrdinal("RecordGuid")),
                    reader.GetString(reader.GetOrdinal("ErrorMessage"))));
            }
        }

        return new RecordExpiryRunResult(lockAcquired, quotesExpired, enquiriesExpired, expiredSilently, failures);
    }
}
