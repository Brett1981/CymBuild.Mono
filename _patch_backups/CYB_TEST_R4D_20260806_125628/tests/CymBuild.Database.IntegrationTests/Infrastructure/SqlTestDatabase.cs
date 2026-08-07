using System.Data;

namespace CymBuild.Database.IntegrationTests.Infrastructure;

internal sealed class SqlTestDatabase
{
    internal const string ConnectionStringEnvironmentVariable = "CYMBUILD_SQL_TEST_CONNECTION_STRING";
    internal const string AllowedDatabaseEnvironmentVariable = "CYMBUILD_SQL_TEST_ALLOWED_DATABASE";

    private SqlTestDatabase(string connectionString, string databaseName)
    {
        ConnectionString = connectionString;
        DatabaseName = databaseName;
    }

    internal string ConnectionString { get; }

    internal string DatabaseName { get; }

    internal static SqlTestDatabase FromEnvironment()
    {
        var rawConnectionString = Environment.GetEnvironmentVariable(ConnectionStringEnvironmentVariable);
        if (string.IsNullOrWhiteSpace(rawConnectionString))
        {
            throw new InvalidOperationException(
                $"Environment variable {ConnectionStringEnvironmentVariable} is required. " +
                "Run tools/Testing/Invoke-CymBuildSqlIntegrationTests.ps1 against a dedicated CymBuild_Test_* database.");
        }

        var builder = new SqlConnectionStringBuilder(rawConnectionString)
        {
            ApplicationName = "CymBuild.Database.IntegrationTests",
            MultipleActiveResultSets = false
        };

        var databaseName = builder.InitialCatalog?.Trim();
        if (string.IsNullOrWhiteSpace(databaseName))
        {
            throw new InvalidOperationException("The SQL integration connection string must include Initial Catalog/Database.");
        }

        var explicitlyAllowedDatabase = Environment.GetEnvironmentVariable(AllowedDatabaseEnvironmentVariable)?.Trim();
        var hasSafePrefix = databaseName.StartsWith("CymBuild_Test_", StringComparison.OrdinalIgnoreCase);
        var isExplicitlyAllowed = !string.IsNullOrWhiteSpace(explicitlyAllowedDatabase)
            && string.Equals(databaseName, explicitlyAllowedDatabase, StringComparison.OrdinalIgnoreCase);

        if (!hasSafePrefix && !isExplicitlyAllowed)
        {
            throw new InvalidOperationException(
                $"Refusing to run SQL integration tests against database '{databaseName}'. " +
                "Use a dedicated database whose name starts with CymBuild_Test_, or explicitly pass -AllowedDatabaseName to the runner.");
        }

        if (databaseName.Equals("master", StringComparison.OrdinalIgnoreCase)
            || databaseName.Equals("model", StringComparison.OrdinalIgnoreCase)
            || databaseName.Equals("msdb", StringComparison.OrdinalIgnoreCase)
            || databaseName.Equals("tempdb", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"Refusing to run SQL integration tests against system database '{databaseName}'.");
        }

        return new SqlTestDatabase(builder.ConnectionString, databaseName);
    }

    internal async Task<SqlConnection> OpenConnectionAsync(CancellationToken cancellationToken = default)
    {
        var connection = new SqlConnection(ConnectionString);
        try
        {
            await connection.OpenAsync(cancellationToken);
            return connection;
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
    }

    internal async Task<int> ExecuteNonQueryAsync(
        string commandText,
        IEnumerable<SqlParameter>? parameters = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = CreateCommand(connection, transaction: null, commandText, parameters);
        return await command.ExecuteNonQueryAsync(cancellationToken);
    }

    internal async Task<T?> ExecuteScalarAsync<T>(
        string commandText,
        IEnumerable<SqlParameter>? parameters = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = CreateCommand(connection, transaction: null, commandText, parameters);
        var value = await command.ExecuteScalarAsync(cancellationToken);
        if (value is null || value is DBNull)
        {
            return default;
        }

        return (T)Convert.ChangeType(value, typeof(T), System.Globalization.CultureInfo.InvariantCulture);
    }

    internal static SqlCommand CreateCommand(
        SqlConnection connection,
        SqlTransaction? transaction,
        string commandText,
        IEnumerable<SqlParameter>? parameters = null,
        CommandType commandType = CommandType.Text)
    {
        var command = new SqlCommand(commandText, connection, transaction)
        {
            CommandType = commandType,
            CommandTimeout = 60
        };

        if (parameters is not null)
        {
            foreach (var parameter in parameters)
            {
                command.Parameters.Add(parameter);
            }
        }

        return command;
    }

    internal static async Task DisableAuditTriggersAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        CancellationToken cancellationToken = default)
    {
        await using var command = CreateCommand(
            connection,
            transaction,
            "EXEC sys.sp_set_session_context @key = N'S_disable_triggers', @value = 1, @read_only = 0;");
        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
