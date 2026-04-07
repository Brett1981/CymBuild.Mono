using Microsoft.Data.SqlClient;
using System.Data;

namespace Concursus.API.Infrastructure.Sql;

public static class SqlSessionContext
{
    /// <summary>
    /// Sets a SQL SESSION_CONTEXT key for the duration of <paramref name="action"/>,
    /// then guarantees it is cleared in a finally block (prevents pooled connection leaks).
    /// </summary>
    public static async Task WithSessionContextAsync(
        SqlConnection con,
        SqlTransaction? tx,
        string key,
        object? value,
        Func<Task> action,
        CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(con);
        ArgumentNullException.ThrowIfNull(key);
        ArgumentNullException.ThrowIfNull(action);

        await SetAsync(con, tx, key, value, ct).ConfigureAwait(false);

        try
        {
            await action().ConfigureAwait(false);
        }
        finally
        {
            // Always clear
            await SetAsync(con, tx, key, DBNull.Value, ct).ConfigureAwait(false);
        }
    }

    /// <summary>
    /// Clears notification-related flags on a freshly opened pooled connection.
    /// Call this immediately after OpenAsync for safety.
    /// </summary>
    public static async Task ClearNotificationFlagsAsync(SqlConnection con, SqlTransaction? tx, CancellationToken ct)
    {
        await SetAsync(con, tx, "S_disable_notification_triggers", DBNull.Value, ct).ConfigureAwait(false);
        // If you still use this anywhere, clear it too:
        await SetAsync(con, tx, "S_disable_triggers", DBNull.Value, ct).ConfigureAwait(false);
    }

    private static async Task SetAsync(SqlConnection con, SqlTransaction? tx, string key, object? value, CancellationToken ct)
    {
        const string sql = "EXEC sys.sp_set_session_context @key=@k, @value=@v;";

        await using var cmd = new SqlCommand(sql, con, tx)
        {
            CommandType = CommandType.Text
        };

        cmd.Parameters.Add(new SqlParameter("@k", SqlDbType.NVarChar, 128) { Value = key });
        cmd.Parameters.Add(new SqlParameter("@v", SqlDbType.Variant) { Value = value ?? DBNull.Value });

        await cmd.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
    }
}