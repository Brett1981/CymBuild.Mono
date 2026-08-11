using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace Concursus.EF;

/// <summary>
/// Installs only the source-controlled SMigration prerequisites required to
/// start the Schema and Metadata Migration workbenches. Application schema and
/// business data are outside this repository's scope.
/// </summary>
public sealed class MigrationBootstrapRepository
{
    private const int BootstrapCommandTimeoutSeconds = 900;
    private const int BootstrapLockTimeoutMilliseconds = 60_000;
    private const string ResourcePrefix = "CymBuild.SqlBootstrap";

    private static readonly Regex GoBatchSeparator = new(
        @"^\s*GO\s*(?:--.*)?$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

    private static readonly BootstrapObjectDefinition[] SchemaRequiredObjects =
    [
        BootstrapObjectDefinition.Schema(10, "SMigration"),
        BootstrapObjectDefinition.Table(20, "SMigration", "Schema_Run"),
        BootstrapObjectDefinition.Table(30, "SMigration", "Schema_ObjectComparisons"),
        BootstrapObjectDefinition.Table(40, "SMigration", "Schema_ValidationIssues"),
        BootstrapObjectDefinition.Table(50, "SMigration", "Schema_ExecutionLog"),
        BootstrapObjectDefinition.Table(60, "SMigration", "Schema_RunSelections"),
        BootstrapObjectDefinition.Table(70, "SMigration", "Schema_ExcludedObjects"),
        BootstrapObjectDefinition.Procedure(80, "SMigration", "SchemaDataObject_Ensure"),
        BootstrapObjectDefinition.Procedure(90, "SMigration", "SchemaDeploymentPlan_Get"),
        BootstrapObjectDefinition.Procedure(100, "SMigration", "SchemaExcludedObject_Apply"),
        BootstrapObjectDefinition.Procedure(110, "SMigration", "SchemaExcludedObjects_List")
    ];

    private static readonly string[] SchemaBootstrapResources =
    [
        $"{ResourcePrefix}.Schema.SMigration.SchemaWorkbench.Bootstrap.sql",
        $"{ResourcePrefix}.Schema.SMigration.SchemaExclusions.Bootstrap.sql"
    ];

    private static readonly BootstrapObjectDefinition[] MetadataRequiredObjects =
    [
        BootstrapObjectDefinition.Schema(
            10,
            "SMigration",
            $"{ResourcePrefix}.Metadata.Schema.SMigration.MetadataWorkbench.Bootstrap.Schema.sql"),

        MetadataTable(100, "Metadata_ApplyIdentityMap"),
        MetadataTable(110, "Metadata_ExecutionLog"),
        MetadataTable(120, "Metadata_IdentityMapIgnoredIssues"),
        MetadataTable(130, "Metadata_IdentityMapOverrides"),
        MetadataTable(140, "Metadata_IgnoredRecords"),
        MetadataTable(150, "Metadata_Run"),
        MetadataTable(160, "Metadata_RunSelections"),
        MetadataTable(170, "Metadata_StagedRows"),
        MetadataTable(180, "Metadata_TableRegistry"),
        MetadataTable(190, "Metadata_ValidationIssues"),

        MetadataProcedure(1000, "MetadataDataObject_Ensure"),
        MetadataProcedure(1010, "MetadataExecutionLog_Add"),
        MetadataProcedure(1020, "MetadataRegistry_Seed"),
        MetadataProcedure(1030, "MetadataRegistry_SyncFromEntityTypes"),
        MetadataProcedure(1040, "MetadataRun_Create"),
        MetadataProcedure(1050, "MetadataRun_Get"),
        MetadataProcedure(1060, "MetadataRun_List"),
        MetadataProcedure(1070, "MetadataEntityTypeScope_List"),
        MetadataProcedure(1080, "MetadataEntityTypeScope_Set"),
        MetadataProcedure(1090, "MetadataRunSelection_Clear"),
        MetadataProcedure(1100, "MetadataRunSelection_Upsert"),
        MetadataProcedure(1110, "MetadataIgnoredRecord_Upsert"),
        MetadataProcedure(1120, "MetadataIgnoredRecords_List"),
        MetadataProcedure(1130, "MetadataIdentityMapIssue_Upsert"),
        MetadataProcedure(1140, "MetadataIdentityMapOverride_Upsert"),
        MetadataProcedure(1150, "MetadataIdentityMapDetails_List"),
        MetadataProcedure(1160, "MetadataApplyIdentityMap_Build"),
        MetadataProcedure(1170, "MetadataStage_NormaliseDifferences"),
        MetadataProcedure(1180, "MetadataStage_NormaliseEnvironmentOnlyUpdates"),
        MetadataProcedure(1190, "MetadataStage_Run"),
        MetadataProcedure(1200, "MetadataValidate_Run"),
        MetadataProcedure(1210, "MetadataApplyPreviewFingerprint_Get"),
        MetadataProcedure(1220, "MetadataApplyPreview_Accept"),
        MetadataProcedure(1230, "MetadataApplyPreview_Get"),
        MetadataProcedure(1240, "MetadataApply_Run")
    ];

    private readonly Assembly _assembly;
    private readonly bool _allowLiveBootstrap;
    private readonly string _connectionString;

    public MigrationBootstrapRepository(IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? configuration.GetConnectionString("ShoreDB")
            ?? configuration.GetConnectionString("CymBuild")
            ?? throw new InvalidOperationException(
                "No database connection string was found for migration bootstrap. Expected one of: DefaultConnection, ShoreDB, CymBuild.");

        _allowLiveBootstrap = bool.TryParse(
            configuration["MigrationBootstrap:AllowLive"],
            out var allowLiveBootstrap)
            && allowLiveBootstrap;
        _assembly = typeof(MigrationBootstrapRepository).Assembly;
    }

    public sealed class MigrationBootstrapException : InvalidOperationException
    {
        public MigrationBootstrapException(string message, Exception innerException)
            : base(message, innerException)
        {
        }
    }

    public sealed record BootstrapResult(
        string BootstrapKind,
        string EnvironmentName,
        string ServerName,
        string DatabaseName,
        bool WasApplied,
        IReadOnlyList<string> MissingBefore,
        IReadOnlyList<string> MissingAfter,
        IReadOnlyList<string> InstalledObjects,
        IReadOnlyDictionary<string, string> ScriptSha256);

    public Task<BootstrapResult> EnsureSchemaWorkbenchAsync(
        string serverName,
        string databaseName,
        string environmentName,
        CancellationToken cancellationToken = default) =>
        EnsureAsync(
            bootstrapKind: "Schema",
            serverName,
            databaseName,
            environmentName,
            SchemaRequiredObjects,
            static missingObjects => missingObjects.Count == 0
                ? []
                : SchemaBootstrapResources,
            cancellationToken);

    public Task<BootstrapResult> EnsureMetadataWorkbenchAsync(
        string serverName,
        string databaseName,
        string environmentName,
        CancellationToken cancellationToken = default) =>
        EnsureAsync(
            bootstrapKind: "Metadata",
            serverName,
            databaseName,
            environmentName,
            MetadataRequiredObjects,
            static missingObjects => missingObjects
                .Select(definition => definition.ResourceName)
                .Where(resourceName => !string.IsNullOrWhiteSpace(resourceName))
                .Distinct(StringComparer.Ordinal)
                .ToArray(),
            cancellationToken);

    private async Task<BootstrapResult> EnsureAsync(
        string bootstrapKind,
        string serverName,
        string databaseName,
        string environmentName,
        IReadOnlyList<BootstrapObjectDefinition> requiredObjects,
        Func<IReadOnlyList<BootstrapObjectDefinition>, IReadOnlyList<string>> resourceSelector,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(databaseName))
        {
            throw new ArgumentException("A target database name is required for migration bootstrap.", nameof(databaseName));
        }

        SqlConnection? connection = null;
        SqlTransaction? transaction = null;

        try
        {
            connection = await OpenConfiguredConnectionAsync(
                serverName,
                databaseName,
                bootstrapKind,
                cancellationToken).ConfigureAwait(false);

            transaction = (SqlTransaction)await connection
                .BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken)
                .ConfigureAwait(false);

            await AcquireBootstrapLockAsync(
                connection,
                transaction,
                bootstrapKind,
                cancellationToken).ConfigureAwait(false);

            var missingBefore = await ReadMissingObjectsAsync(
                connection,
                transaction,
                requiredObjects,
                cancellationToken).ConfigureAwait(false);

            if (missingBefore.Count > 0
                && IsLiveLikeEndpoint(environmentName, connection.DataSource, connection.Database)
                && !_allowLiveBootstrap)
            {
                throw new InvalidOperationException(
                    "The selected endpoint appears to be LIVE/production. Automatic bootstrap is disabled by default. " +
                    "Set MigrationBootstrap:AllowLive=true only in the approved LIVE release configuration for the controlled deployment identity.");
            }

            var scriptHashes = new Dictionary<string, string>(StringComparer.Ordinal);
            var resources = resourceSelector(missingBefore);

            foreach (var resourceName in resources)
            {
                var scriptHash = await ExecuteEmbeddedSqlScriptAsync(
                    connection,
                    transaction,
                    resourceName,
                    cancellationToken).ConfigureAwait(false);

                scriptHashes.Add(resourceName, scriptHash);
            }

            var missingAfter = await ReadMissingObjectsAsync(
                connection,
                transaction,
                requiredObjects,
                cancellationToken).ConfigureAwait(false);

            if (missingAfter.Count > 0)
            {
                throw new InvalidOperationException(
                    $"Bootstrap verification found missing objects: {string.Join(", ", missingAfter.Select(item => item.DisplayName))}.");
            }

            await transaction.CommitAsync(cancellationToken).ConfigureAwait(false);

            return new BootstrapResult(
                BootstrapKind: bootstrapKind,
                EnvironmentName: environmentName?.Trim() ?? string.Empty,
                ServerName: connection.DataSource,
                DatabaseName: connection.Database,
                WasApplied: resources.Count > 0,
                MissingBefore: missingBefore.Select(item => item.DisplayName).ToArray(),
                MissingAfter: missingAfter.Select(item => item.DisplayName).ToArray(),
                InstalledObjects: missingBefore.Select(item => item.DisplayName).ToArray(),
                ScriptSha256: scriptHashes);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            if (transaction is not null)
            {
                await TryRollbackAsync(transaction).ConfigureAwait(false);
            }

            var endpoint = connection is null
                ? $"{serverName} / {databaseName}"
                : $"{connection.DataSource} / {connection.Database}";

            throw new MigrationBootstrapException(
                $"Automatic {bootstrapKind} Migration bootstrap failed for '{endpoint}'. " +
                "No migration run was created and the bootstrap transaction was rolled back. " +
                "Confirm the API or controlled pipeline deployment identity has CREATE/ALTER permission on the selected database. " +
                ex.Message,
                ex);
        }
        finally
        {
            if (transaction is not null)
            {
                await transaction.DisposeAsync().ConfigureAwait(false);
            }

            if (connection is not null)
            {
                await connection.DisposeAsync().ConfigureAwait(false);
            }
        }
    }

    private async Task<SqlConnection> OpenConfiguredConnectionAsync(
        string serverName,
        string databaseName,
        string bootstrapKind,
        CancellationToken cancellationToken)
    {
        var builder = new SqlConnectionStringBuilder(_connectionString)
        {
            InitialCatalog = databaseName.Trim(),
            ApplicationName = $"CymBuild.{bootstrapKind}MigrationBootstrap"
        };

        if (!string.IsNullOrWhiteSpace(serverName))
        {
            builder.DataSource = serverName.Trim();
        }

        var connection = new SqlConnection(builder.ConnectionString);
        try
        {
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);
            return connection;
        }
        catch
        {
            await connection.DisposeAsync().ConfigureAwait(false);
            throw;
        }
    }

    private static async Task AcquireBootstrapLockAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string bootstrapKind,
        CancellationToken cancellationToken)
    {
        const string sql = """
            DECLARE @LockResult INT;

            EXEC @LockResult = sys.sp_getapplock
                @Resource = @Resource,
                @LockMode = N'Exclusive',
                @LockOwner = N'Transaction',
                @LockTimeout = @LockTimeout;

            SELECT @LockResult;
            """;

        await using var command = new SqlCommand(sql, connection, transaction)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 90
        };

        command.Parameters.Add(new SqlParameter("@Resource", SqlDbType.NVarChar, 255)
        {
            Value = $"CymBuild.{bootstrapKind}MigrationBootstrap"
        });
        command.Parameters.Add(new SqlParameter("@LockTimeout", SqlDbType.Int)
        {
            Value = BootstrapLockTimeoutMilliseconds
        });

        var result = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false));
        if (result < 0)
        {
            throw new TimeoutException(
                $"Could not acquire the {bootstrapKind} Migration bootstrap lock. SQL result: {result}.");
        }
    }

    private static async Task<IReadOnlyList<BootstrapObjectDefinition>> ReadMissingObjectsAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        IReadOnlyList<BootstrapObjectDefinition> requiredObjects,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT CONVERT
            (
                BIT,
                CASE
                    WHEN @ObjectKind = N'Schema'
                        THEN CASE WHEN SCHEMA_ID(@SchemaName) IS NULL THEN 0 ELSE 1 END
                    WHEN OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@ObjectName), @ObjectTypeCode) IS NULL
                        THEN 0
                    ELSE 1
                END
            );
            """;

        var missingObjects = new List<BootstrapObjectDefinition>();

        foreach (var requiredObject in requiredObjects.OrderBy(item => item.SortOrder))
        {
            await using var command = new SqlCommand(sql, connection, transaction)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 300
            };

            command.Parameters.Add(new SqlParameter("@ObjectKind", SqlDbType.NVarChar, 20)
            {
                Value = requiredObject.ObjectKind
            });
            command.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128)
            {
                Value = requiredObject.SchemaName
            });
            command.Parameters.Add(new SqlParameter("@ObjectName", SqlDbType.NVarChar, 128)
            {
                Value = requiredObject.ObjectName
            });
            command.Parameters.Add(new SqlParameter("@ObjectTypeCode", SqlDbType.NVarChar, 2)
            {
                Value = requiredObject.ObjectTypeCode
            });

            var isPresent = Convert.ToBoolean(
                await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false));

            if (!isPresent)
            {
                missingObjects.Add(requiredObject);
            }
        }

        return missingObjects;
    }

    private async Task<string> ExecuteEmbeddedSqlScriptAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string resourceName,
        CancellationToken cancellationToken)
    {
        await using var resourceStream = _assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException(
                $"Embedded source-controlled bootstrap resource was not found: {resourceName}.");

        await using var buffer = new MemoryStream();
        await resourceStream.CopyToAsync(buffer, cancellationToken).ConfigureAwait(false);
        var scriptBytes = buffer.ToArray();
        var scriptHash = Convert.ToHexString(SHA256.HashData(scriptBytes)).ToLowerInvariant();
        var scriptText = Encoding.UTF8.GetString(scriptBytes).TrimStart('\uFEFF');
        var batches = SplitSqlBatches(scriptText);

        if (batches.Count == 0)
        {
            throw new InvalidOperationException(
                $"Embedded source-controlled bootstrap resource contained no executable SQL: {resourceName}.");
        }

        for (var batchIndex = 0; batchIndex < batches.Count; batchIndex++)
        {
            await using var command = new SqlCommand(batches[batchIndex], connection, transaction)
            {
                CommandType = CommandType.Text,
                CommandTimeout = BootstrapCommandTimeoutSeconds
            };

            try
            {
                await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
            }
            catch (SqlException ex)
            {
                throw new InvalidOperationException(
                    $"Bootstrap resource '{resourceName}' failed in batch {batchIndex + 1} of {batches.Count}: {ex.Message}",
                    ex);
            }
        }

        return scriptHash;
    }

    private static IReadOnlyList<string> SplitSqlBatches(string scriptText)
    {
        var batches = new List<string>();
        var currentBatch = new StringBuilder();

        using var reader = new StringReader(scriptText);
        while (reader.ReadLine() is { } line)
        {
            if (GoBatchSeparator.IsMatch(line))
            {
                AddCurrentBatch(batches, currentBatch);
                continue;
            }

            currentBatch.AppendLine(line);
        }

        AddCurrentBatch(batches, currentBatch);
        return batches;
    }

    private static void AddCurrentBatch(List<string> batches, StringBuilder currentBatch)
    {
        var batch = currentBatch.ToString().Trim();
        if (!string.IsNullOrWhiteSpace(batch))
        {
            batches.Add(batch);
        }

        currentBatch.Clear();
    }

    private static async Task TryRollbackAsync(SqlTransaction transaction)
    {
        try
        {
            await transaction.RollbackAsync(CancellationToken.None).ConfigureAwait(false);
        }
        catch (Exception ex) when (ex is InvalidOperationException or SqlException)
        {
            // The transaction was already committed, rolled back, or disconnected.
        }
    }

    private static bool IsLiveLikeEndpoint(
        string environmentName,
        string serverName,
        string databaseName)
    {
        static bool IsLiveLikeValue(string value)
        {
            var normalised = (value ?? string.Empty).Trim().ToUpperInvariant();
            return normalised.Contains("LIVE", StringComparison.Ordinal)
                || normalised.Contains("PROD", StringComparison.Ordinal)
                || normalised.Contains("PRODUCTION", StringComparison.Ordinal);
        }

        return IsLiveLikeValue(environmentName)
            || IsLiveLikeValue(serverName)
            || IsLiveLikeValue(databaseName);
    }

    private static BootstrapObjectDefinition MetadataTable(int sortOrder, string objectName) =>
        BootstrapObjectDefinition.Table(
            sortOrder,
            "SMigration",
            objectName,
            $"{ResourcePrefix}.Metadata.Tables.SMigration.{objectName}.sql");

    private static BootstrapObjectDefinition MetadataProcedure(int sortOrder, string objectName) =>
        BootstrapObjectDefinition.Procedure(
            sortOrder,
            "SMigration",
            objectName,
            $"{ResourcePrefix}.Metadata.Procedures.SMigration.{objectName}.sql");

    private sealed record BootstrapObjectDefinition(
        int SortOrder,
        string ObjectKind,
        string SchemaName,
        string ObjectName,
        string ObjectTypeCode,
        string ResourceName)
    {
        public string DisplayName => ObjectKind == "Schema"
            ? $"Schema [{SchemaName}]"
            : $"{ObjectKind} [{SchemaName}].[{ObjectName}]";

        public static BootstrapObjectDefinition Schema(
            int sortOrder,
            string schemaName,
            string resourceName = "") =>
            new(sortOrder, "Schema", schemaName, string.Empty, string.Empty, resourceName);

        public static BootstrapObjectDefinition Table(
            int sortOrder,
            string schemaName,
            string objectName,
            string resourceName = "") =>
            new(sortOrder, "Table", schemaName, objectName, "U", resourceName);

        public static BootstrapObjectDefinition Procedure(
            int sortOrder,
            string schemaName,
            string objectName,
            string resourceName = "") =>
            new(sortOrder, "Procedure", schemaName, objectName, "P", resourceName);
    }
}
