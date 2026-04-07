// File: Services/InvoiceAutomation/SqlDistributedAppLock.cs
using Microsoft.Data.SqlClient;

namespace Concursus.API.Services.InvoiceAutomation;

public static class SqlDistributedAppLock
{
    public static async Task<bool> TryAcquireExclusiveAsync(
        SqlConnection connection,
        SqlTransaction? tx,
        string resource,
        int timeoutMs,
        CancellationToken ct)
    {
        var (acquired, _) = await TryAcquireExclusiveWithResultAsync(connection, tx, resource, timeoutMs, ct);
        return acquired;
    }

    /// <summary>
    /// Returns (acquired, returnCode).
    /// sp_getapplock return codes:
    ///  0 = lock granted
    ///  1 = lock granted after wait
    /// -1 = timeout
    /// -2 = cancelled
    /// -3 = deadlock victim
    /// -999 = parameter validation or other error
    /// </summary>
    public static async Task<(bool acquired, int returnCode)> TryAcquireExclusiveWithResultAsync(
        SqlConnection connection,
        SqlTransaction? tx,
        string resource,
        int timeoutMs,
        CancellationToken ct)
    {
        using var cmd = new SqlCommand("sp_getapplock", connection, tx)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Resource", resource);
        cmd.Parameters.AddWithValue("@LockMode", "Exclusive");
        cmd.Parameters.AddWithValue("@LockOwner", "Session");
        cmd.Parameters.AddWithValue("@LockTimeout", timeoutMs);

        var returnParam = cmd.Parameters.Add("@ReturnCode", System.Data.SqlDbType.Int);
        returnParam.Direction = System.Data.ParameterDirection.ReturnValue;

        await cmd.ExecuteNonQueryAsync(ct);

        var rc = (int)(returnParam.Value ?? -999);
        var acquired = rc is 0 or 1;
        return (acquired, rc);
    }

    public static async Task ReleaseAsync(
        SqlConnection connection,
        SqlTransaction? tx,
        string resource,
        CancellationToken ct)
    {
        using var cmd = new SqlCommand("sp_releaseapplock", connection, tx)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Resource", resource);
        cmd.Parameters.AddWithValue("@LockOwner", "Session");

        await cmd.ExecuteNonQueryAsync(ct);
    }
}