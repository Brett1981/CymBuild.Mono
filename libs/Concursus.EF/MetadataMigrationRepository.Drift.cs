using Microsoft.Data.SqlClient;
using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Concursus.EF;

public sealed partial class MetadataMigrationRepository
{
    public sealed class MetadataMigrationDriftException : InvalidOperationException
    {
        public MetadataMigrationDriftException(string message)
            : base(message)
        {
        }
    }

    public sealed record ApplyPreviewRowResult(
        string SchemaName,
        string TableName,
        Guid SourceRowGuid,
        long SourceRowId,
        string DifferenceType,
        bool IsSelected,
        bool IsIgnored,
        bool HasValidationFailure,
        string ApplyAction,
        string SkipReason,
        string ChangedColumns,
        int RunValidationFailureCount);

    public sealed record ApplyPreviewResult(
        IReadOnlyList<ApplyPreviewRowResult> Rows,
        string PreviewFingerprint,
        bool IsAccepted,
        string AcceptedOnUtc,
        int AcceptedByUserId);

    private sealed record RunDefinition(
        string SourceServerName,
        string SourceDatabaseName,
        string TargetServerName,
        string TargetDatabaseName);

    private sealed record RegistryDefinition(
        Guid RegistryGuid,
        string SchemaName,
        string TableName,
        string GuidColumnName,
        string PrimaryKeyColumnName,
        int ApplyOrder,
        IReadOnlyList<StagedSnapshotRow> StagedRows);

    private sealed record StagedSnapshotRow(
        Guid SourceRowGuid,
        string SourcePayloadJson,
        byte[] SourcePayloadHash,
        string? TargetPayloadJson,
        byte[]? TargetPayloadHash);

    private sealed record PayloadRow(Guid RowGuid, string PayloadJson);

    private sealed record DriftSnapshot(string SourceFingerprint, string TargetFingerprint);

    public async Task<ApplyPreviewResult> GetApplyPreviewAsync(
        Guid runGuid,
        bool applySelectedOnly,
        bool includeIgnored,
        string targetServerName,
        string targetDatabaseName,
        CancellationToken cancellationToken = default)
    {
        ValidateRunAndTargetArguments(runGuid, targetServerName, targetDatabaseName);

        await using var targetConnection = await OpenConfiguredConnectionAsync(
            targetServerName,
            targetDatabaseName,
            cancellationToken).ConfigureAwait(false);

        var run = await ReadRunDefinitionAsync(
            targetConnection,
            transaction: null,
            runGuid,
            cancellationToken).ConfigureAwait(false);

        ValidateRunEndpoints(run, targetServerName, targetDatabaseName);

        await using var sourceConnection = await OpenConfiguredConnectionAsync(
            run.SourceServerName,
            run.SourceDatabaseName,
            cancellationToken).ConfigureAwait(false);

        var snapshot = await ReadAndValidateDriftSnapshotAsync(
            sourceConnection,
            sourceTransaction: null,
            targetConnection,
            targetTransaction: null,
            runGuid,
            cancellationToken).ConfigureAwait(false);

        return await ReadApplyPreviewAsync(
            targetConnection,
            transaction: null,
            runGuid,
            applySelectedOnly,
            includeIgnored,
            snapshot,
            cancellationToken).ConfigureAwait(false);
    }

    private async Task<ApplyPreviewAcceptanceResult> AcceptApplyPreviewWithDriftAsync(
        Guid runGuid,
        bool applySelectedOnly,
        string expectedPreviewFingerprint,
        string targetServerName,
        string targetDatabaseName,
        CancellationToken cancellationToken)
    {
        ValidateRunAndTargetArguments(runGuid, targetServerName, targetDatabaseName);
        ValidateFingerprint(expectedPreviewFingerprint, nameof(expectedPreviewFingerprint));

        await using var targetConnection = await OpenConfiguredConnectionAsync(
            targetServerName,
            targetDatabaseName,
            cancellationToken).ConfigureAwait(false);

        await using var targetTransaction = (SqlTransaction)await targetConnection
            .BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken)
            .ConfigureAwait(false);

        SqlConnection? sourceConnection = null;
        SqlTransaction? sourceTransaction = null;

        try
        {
            var run = await ReadRunDefinitionAsync(
                targetConnection,
                targetTransaction,
                runGuid,
                cancellationToken).ConfigureAwait(false);

            ValidateRunEndpoints(run, targetServerName, targetDatabaseName);

            sourceConnection = await OpenConfiguredConnectionAsync(
                run.SourceServerName,
                run.SourceDatabaseName,
                cancellationToken).ConfigureAwait(false);

            sourceTransaction = (SqlTransaction)await sourceConnection
                .BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken)
                .ConfigureAwait(false);

            var snapshot = await ReadAndValidateDriftSnapshotAsync(
                sourceConnection,
                sourceTransaction,
                targetConnection,
                targetTransaction,
                runGuid,
                cancellationToken).ConfigureAwait(false);

            var result = await ExecuteAcceptApplyPreviewAsync(
                targetConnection,
                targetTransaction,
                runGuid,
                applySelectedOnly,
                expectedPreviewFingerprint,
                snapshot,
                cancellationToken).ConfigureAwait(false);

            await sourceTransaction.CommitAsync(cancellationToken).ConfigureAwait(false);
            await targetTransaction.CommitAsync(cancellationToken).ConfigureAwait(false);

            return result;
        }
        catch
        {
            await TryRollbackAsync(targetTransaction, cancellationToken).ConfigureAwait(false);
            if (sourceTransaction is not null)
            {
                await TryRollbackAsync(sourceTransaction, cancellationToken).ConfigureAwait(false);
            }

            throw;
        }
        finally
        {
            if (sourceTransaction is not null)
            {
                await sourceTransaction.DisposeAsync().ConfigureAwait(false);
            }

            if (sourceConnection is not null)
            {
                await sourceConnection.DisposeAsync().ConfigureAwait(false);
            }
        }
    }

    public async Task ApplyAsync(
        Guid runGuid,
        bool forceApply,
        bool applySelectedOnly,
        string targetServerName,
        string targetDatabaseName,
        CancellationToken cancellationToken = default)
    {
        ValidateRunAndTargetArguments(runGuid, targetServerName, targetDatabaseName);

        await using var targetConnection = await OpenConfiguredConnectionAsync(
            targetServerName,
            targetDatabaseName,
            cancellationToken).ConfigureAwait(false);

        await using var targetTransaction = (SqlTransaction)await targetConnection
            .BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken)
            .ConfigureAwait(false);

        SqlConnection? sourceConnection = null;
        SqlTransaction? sourceTransaction = null;

        try
        {
            var run = await ReadRunDefinitionAsync(
                targetConnection,
                targetTransaction,
                runGuid,
                cancellationToken).ConfigureAwait(false);

            ValidateRunEndpoints(run, targetServerName, targetDatabaseName);

            sourceConnection = await OpenConfiguredConnectionAsync(
                run.SourceServerName,
                run.SourceDatabaseName,
                cancellationToken).ConfigureAwait(false);

            sourceTransaction = (SqlTransaction)await sourceConnection
                .BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken)
                .ConfigureAwait(false);

            var snapshot = await ReadAndValidateDriftSnapshotAsync(
                sourceConnection,
                sourceTransaction,
                targetConnection,
                targetTransaction,
                runGuid,
                cancellationToken).ConfigureAwait(false);

            await ExecuteApplyAsync(
                targetConnection,
                targetTransaction,
                runGuid,
                forceApply,
                applySelectedOnly,
                snapshot,
                cancellationToken).ConfigureAwait(false);

            await sourceTransaction.CommitAsync(cancellationToken).ConfigureAwait(false);
            await targetTransaction.CommitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            await TryRollbackAsync(targetTransaction, cancellationToken).ConfigureAwait(false);
            if (sourceTransaction is not null)
            {
                await TryRollbackAsync(sourceTransaction, cancellationToken).ConfigureAwait(false);
            }

            throw;
        }
        finally
        {
            if (sourceTransaction is not null)
            {
                await sourceTransaction.DisposeAsync().ConfigureAwait(false);
            }

            if (sourceConnection is not null)
            {
                await sourceConnection.DisposeAsync().ConfigureAwait(false);
            }
        }
    }

    private async Task<SqlConnection> OpenConfiguredConnectionAsync(
        string serverName,
        string databaseName,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(serverName))
        {
            throw new ArgumentException("A SQL Server name is required.", nameof(serverName));
        }

        if (string.IsNullOrWhiteSpace(databaseName))
        {
            throw new ArgumentException("A database name is required.", nameof(databaseName));
        }

        var builder = new SqlConnectionStringBuilder(_connectionString)
        {
            DataSource = serverName.Trim(),
            InitialCatalog = databaseName.Trim()
        };

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

    private static async Task<RunDefinition> ReadRunDefinitionAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT
                r.SourceServerName,
                r.SourceDatabaseName,
                r.TargetServerName,
                r.TargetDatabaseName
            FROM SMigration.Metadata_Run AS r WITH (HOLDLOCK)
            WHERE r.Guid = @RunGuid
              AND r.RowStatus NOT IN (0,254);
            """;

        await using var command = new SqlCommand(sql, connection, transaction)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        command.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            throw new InvalidOperationException("The metadata migration run was not found or is inactive.");
        }

        return new RunDefinition(
            SourceServerName: Convert.ToString(reader["SourceServerName"]) ?? string.Empty,
            SourceDatabaseName: Convert.ToString(reader["SourceDatabaseName"]) ?? string.Empty,
            TargetServerName: Convert.ToString(reader["TargetServerName"]) ?? string.Empty,
            TargetDatabaseName: Convert.ToString(reader["TargetDatabaseName"]) ?? string.Empty);
    }

    private static async Task<DriftSnapshot> ReadAndValidateDriftSnapshotAsync(
        SqlConnection sourceConnection,
        SqlTransaction? sourceTransaction,
        SqlConnection targetConnection,
        SqlTransaction? targetTransaction,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        var registries = await ReadRegistryDefinitionsAsync(
            targetConnection,
            targetTransaction,
            runGuid,
            cancellationToken).ConfigureAwait(false);

        if (registries.Count == 0)
        {
            throw new MetadataMigrationDriftException(
                "Metadata drift validation found no enabled registry rows. Re-stage and validate the run before deployment.");
        }

        var sourceEntries = new List<string>();
        var targetEntries = new List<string>();

        foreach (var registry in registries)
        {
            ValidateSqlIdentifier(registry.SchemaName, nameof(registry.SchemaName));
            ValidateSqlIdentifier(registry.TableName, nameof(registry.TableName));
            ValidateSqlIdentifier(registry.GuidColumnName, nameof(registry.GuidColumnName));
            ValidateSqlIdentifier(registry.PrimaryKeyColumnName, nameof(registry.PrimaryKeyColumnName));

            var targetColumns = await ReadColumnNamesAsync(
                targetConnection,
                targetTransaction,
                registry.SchemaName,
                registry.TableName,
                cancellationToken).ConfigureAwait(false);

            if (targetColumns.Count == 0)
            {
                throw Drift(registry, null, "the registered target table or its deployable columns no longer exist");
            }

            var sourceColumns = await ReadColumnNamesAsync(
                sourceConnection,
                sourceTransaction,
                registry.SchemaName,
                registry.TableName,
                cancellationToken).ConfigureAwait(false);

            var missingSourceColumns = targetColumns
                .Where(column => !sourceColumns.Contains(column, StringComparer.OrdinalIgnoreCase))
                .ToArray();

            if (missingSourceColumns.Length > 0)
            {
                throw Drift(
                    registry,
                    null,
                    $"the source table no longer contains target column(s): {string.Join(", ", missingSourceColumns)}");
            }

            var sourceRows = await ReadPayloadRowsAsync(
                sourceConnection,
                sourceTransaction,
                registry,
                targetColumns,
                activeOnly: true,
                cancellationToken).ConfigureAwait(false);

            var targetRows = await ReadPayloadRowsAsync(
                targetConnection,
                targetTransaction,
                registry,
                targetColumns,
                activeOnly: false,
                cancellationToken).ConfigureAwait(false);

            var sourceByGuid = BuildUniquePayloadIndex(sourceRows, registry, "source");
            var targetByGuid = BuildUniquePayloadIndex(targetRows, registry, "target");
            var stagedByGuid = registry.StagedRows.ToDictionary(row => row.SourceRowGuid);

            if (!sourceByGuid.Keys.ToHashSet().SetEquals(stagedByGuid.Keys))
            {
                throw Drift(
                    registry,
                    null,
                    "the active source row set changed after staging (a row was added, removed or retired)");
            }

            foreach (var stagedRow in registry.StagedRows)
            {
                ValidateStoredPayloadHash(
                    registry,
                    stagedRow.SourceRowGuid,
                    "source",
                    stagedRow.SourcePayloadJson,
                    stagedRow.SourcePayloadHash);

                if (!sourceByGuid.TryGetValue(stagedRow.SourceRowGuid, out var currentSourceRow)
                    || !PayloadsEquivalent(stagedRow.SourcePayloadJson, currentSourceRow.PayloadJson))
                {
                    throw Drift(registry, stagedRow.SourceRowGuid, "the source payload changed after staging");
                }

                if (stagedRow.TargetPayloadJson is null || stagedRow.TargetPayloadHash is null)
                {
                    if (targetByGuid.ContainsKey(stagedRow.SourceRowGuid))
                    {
                        throw Drift(registry, stagedRow.SourceRowGuid, "the target row was created after staging");
                    }

                    continue;
                }

                ValidateStoredPayloadHash(
                    registry,
                    stagedRow.SourceRowGuid,
                    "target",
                    stagedRow.TargetPayloadJson,
                    stagedRow.TargetPayloadHash);

                var expectedTargetGuid = ReadPayloadGuid(
                    stagedRow.TargetPayloadJson,
                    registry.GuidColumnName,
                    stagedRow.SourceRowGuid);

                if (!targetByGuid.TryGetValue(expectedTargetGuid, out var currentTargetRow)
                    || !PayloadsEquivalent(stagedRow.TargetPayloadJson, currentTargetRow.PayloadJson))
                {
                    throw Drift(registry, stagedRow.SourceRowGuid, "the target payload changed after staging");
                }
            }

            var columnEnvelope = string.Join(",", targetColumns);
            sourceEntries.Add($"registry|{registry.ApplyOrder}|{registry.RegistryGuid:D}|{registry.SchemaName}|{registry.TableName}|{columnEnvelope}");
            targetEntries.Add($"registry|{registry.ApplyOrder}|{registry.RegistryGuid:D}|{registry.SchemaName}|{registry.TableName}|{columnEnvelope}");

            sourceEntries.AddRange(sourceRows.Select(row => BuildSnapshotRowEntry(registry, row)));
            targetEntries.AddRange(targetRows.Select(row => BuildSnapshotRowEntry(registry, row)));
        }

        return new DriftSnapshot(
            SourceFingerprint: ComputeAggregateFingerprint(sourceEntries),
            TargetFingerprint: ComputeAggregateFingerprint(targetEntries));
    }

    private static async Task<IReadOnlyList<RegistryDefinition>> ReadRegistryDefinitionsAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT
                tr.Guid AS RegistryGuid,
                tr.SchemaName,
                tr.TableName,
                tr.GuidColumnName,
                tr.PrimaryKeyColumnName,
                tr.ApplyOrder,
                sr.SourceRowGuid,
                sr.SourcePayloadJson,
                sr.SourcePayloadHash,
                sr.TargetPayloadJson,
                sr.TargetPayloadHash
            FROM SMigration.Metadata_TableRegistry AS tr WITH (HOLDLOCK)
            LEFT JOIN SMigration.Metadata_StagedRows AS sr WITH (HOLDLOCK)
                ON sr.RunGuid = @RunGuid
               AND sr.RegistryGuid = tr.Guid
               AND sr.RowStatus NOT IN (0,254)
            WHERE tr.RowStatus NOT IN (0,254)
              AND tr.IsEnabled = 1
            ORDER BY
                tr.ApplyOrder,
                tr.SchemaName,
                tr.TableName,
                sr.SourceRowGuid;
            """;

        await using var command = new SqlCommand(sql, connection, transaction)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 600
        };

        command.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        var builders = new Dictionary<Guid, RegistryDefinitionBuilder>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            var registryGuid = (Guid)reader["RegistryGuid"];
            if (!builders.TryGetValue(registryGuid, out var builder))
            {
                builder = new RegistryDefinitionBuilder
                {
                    RegistryGuid = registryGuid,
                    SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                    TableName = Convert.ToString(reader["TableName"]) ?? string.Empty,
                    GuidColumnName = Convert.ToString(reader["GuidColumnName"]) ?? string.Empty,
                    PrimaryKeyColumnName = Convert.ToString(reader["PrimaryKeyColumnName"]) ?? string.Empty,
                    ApplyOrder = Convert.ToInt32(reader["ApplyOrder"])
                };
                builders.Add(registryGuid, builder);
            }

            if (reader["SourceRowGuid"] != DBNull.Value)
            {
                builder.StagedRows.Add(new StagedSnapshotRow(
                    SourceRowGuid: (Guid)reader["SourceRowGuid"],
                    SourcePayloadJson: Convert.ToString(reader["SourcePayloadJson"]) ?? "{}",
                    SourcePayloadHash: (byte[])reader["SourcePayloadHash"],
                    TargetPayloadJson: reader["TargetPayloadJson"] == DBNull.Value
                        ? null
                        : Convert.ToString(reader["TargetPayloadJson"]),
                    TargetPayloadHash: reader["TargetPayloadHash"] == DBNull.Value
                        ? null
                        : (byte[])reader["TargetPayloadHash"]));
            }
        }

        return builders.Values
            .OrderBy(builder => builder.ApplyOrder)
            .ThenBy(builder => builder.SchemaName, StringComparer.Ordinal)
            .ThenBy(builder => builder.TableName, StringComparer.Ordinal)
            .Select(builder => builder.Build())
            .ToArray();
    }

    private sealed class RegistryDefinitionBuilder
    {
        public Guid RegistryGuid { get; init; }
        public string SchemaName { get; init; } = string.Empty;
        public string TableName { get; init; } = string.Empty;
        public string GuidColumnName { get; init; } = string.Empty;
        public string PrimaryKeyColumnName { get; init; } = string.Empty;
        public int ApplyOrder { get; init; }
        public List<StagedSnapshotRow> StagedRows { get; } = [];

        public RegistryDefinition Build() => new(
            RegistryGuid,
            SchemaName,
            TableName,
            GuidColumnName,
            PrimaryKeyColumnName,
            ApplyOrder,
            StagedRows);
    }

    private static async Task<IReadOnlyList<string>> ReadColumnNamesAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        string schemaName,
        string tableName,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT
                c.name
            FROM sys.schemas AS s
            INNER JOIN sys.tables AS t
                ON t.schema_id = s.schema_id
            INNER JOIN sys.columns AS c
                ON c.object_id = t.object_id
            WHERE s.name = @SchemaName
              AND t.name = @TableName
              AND c.is_computed = 0
              AND c.system_type_id <> 189
            ORDER BY c.column_id;
            """;

        await using var command = new SqlCommand(sql, connection, transaction)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        command.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = schemaName });
        command.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = tableName });

        var columns = new List<string>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            columns.Add(Convert.ToString(reader["name"]) ?? string.Empty);
        }

        return columns;
    }

    private static async Task<IReadOnlyList<PayloadRow>> ReadPayloadRowsAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        RegistryDefinition registry,
        IReadOnlyList<string> columnNames,
        bool activeOnly,
        CancellationToken cancellationToken)
    {
        var qualifiedColumns = string.Join(", ", columnNames.Select(column => $"sj.{QuoteName(column)}"));
        var objectName = $"{QuoteName(registry.SchemaName)}.{QuoteName(registry.TableName)}";
        var hasRowStatus = columnNames.Contains("RowStatus", StringComparer.OrdinalIgnoreCase);
        var activeFilter = activeOnly && hasRowStatus
            ? "WHERE s.[RowStatus] NOT IN (0,254)"
            : string.Empty;

        var sql = $"""
            SELECT
                CONVERT(UNIQUEIDENTIFIER, s.{QuoteName(registry.GuidColumnName)}) AS RowGuid,
                (
                    SELECT {qualifiedColumns}
                    FROM {objectName} AS sj WITH (HOLDLOCK)
                    WHERE sj.{QuoteName(registry.GuidColumnName)} = s.{QuoteName(registry.GuidColumnName)}
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                ) AS PayloadJson
            FROM {objectName} AS s WITH (HOLDLOCK)
            {activeFilter};
            """;

        await using var command = new SqlCommand(sql, connection, transaction)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 600
        };

        var rows = new List<PayloadRow>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            rows.Add(new PayloadRow(
                RowGuid: (Guid)reader["RowGuid"],
                PayloadJson: Convert.ToString(reader["PayloadJson"]) ?? "{}"));
        }

        return rows;
    }

    private static async Task<ApplyPreviewResult> ReadApplyPreviewAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid runGuid,
        bool applySelectedOnly,
        bool includeIgnored,
        DriftSnapshot snapshot,
        CancellationToken cancellationToken)
    {
        await using var command = new SqlCommand("SMigration.MetadataApplyPreview_Get", connection, transaction)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        AddFingerprintParameters(command, runGuid, applySelectedOnly, snapshot);
        command.Parameters.Add(new SqlParameter("@IncludeIgnored", SqlDbType.Bit) { Value = includeIgnored });

        var rows = new List<ApplyPreviewRowResult>();
        var previewFingerprint = string.Empty;
        var isAccepted = false;
        var acceptedOnUtc = string.Empty;
        var acceptedByUserId = -1;

        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            rows.Add(new ApplyPreviewRowResult(
                SchemaName: Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                TableName: Convert.ToString(reader["TableName"]) ?? string.Empty,
                SourceRowGuid: (Guid)reader["SourceRowGuid"],
                SourceRowId: Convert.ToInt64(reader["SourceRowId"]),
                DifferenceType: Convert.ToString(reader["DifferenceType"]) ?? string.Empty,
                IsSelected: Convert.ToBoolean(reader["IsSelected"]),
                IsIgnored: Convert.ToBoolean(reader["IsIgnored"]),
                HasValidationFailure: Convert.ToBoolean(reader["HasValidationFailure"]),
                ApplyAction: Convert.ToString(reader["ApplyAction"]) ?? string.Empty,
                SkipReason: Convert.ToString(reader["SkipReason"]) ?? string.Empty,
                ChangedColumns: Convert.ToString(reader["ChangedColumns"]) ?? string.Empty,
                RunValidationFailureCount: Convert.ToInt32(reader["RunValidationFailureCount"])));
        }

        if (await reader.NextResultAsync(cancellationToken).ConfigureAwait(false)
            && await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            previewFingerprint = Convert.ToString(reader["PreviewFingerprint"]) ?? string.Empty;
            isAccepted = Convert.ToBoolean(reader["IsAccepted"]);
            acceptedOnUtc = Convert.ToString(reader["AcceptedOnUtc"]) ?? string.Empty;
            acceptedByUserId = Convert.ToInt32(reader["AcceptedByUserId"]);
        }

        ValidateFingerprint(previewFingerprint, nameof(previewFingerprint));

        return new ApplyPreviewResult(
            Rows: rows,
            PreviewFingerprint: previewFingerprint,
            IsAccepted: isAccepted,
            AcceptedOnUtc: acceptedOnUtc,
            AcceptedByUserId: acceptedByUserId);
    }

    private static async Task<ApplyPreviewAcceptanceResult> ExecuteAcceptApplyPreviewAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid runGuid,
        bool applySelectedOnly,
        string expectedPreviewFingerprint,
        DriftSnapshot snapshot,
        CancellationToken cancellationToken)
    {
        await using var command = new SqlCommand("SMigration.MetadataApplyPreview_Accept", connection, transaction)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        AddFingerprintParameters(command, runGuid, applySelectedOnly, snapshot);
        command.Parameters.Add(new SqlParameter("@ExpectedPreviewFingerprint", SqlDbType.VarChar, 64)
        {
            Value = expectedPreviewFingerprint.ToUpperInvariant()
        });

        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            throw new InvalidOperationException("Metadata apply preview acceptance returned no result.");
        }

        return new ApplyPreviewAcceptanceResult(
            IsAccepted: Convert.ToBoolean(reader["IsAccepted"]),
            ApplySelectedOnly: Convert.ToBoolean(reader["ApplySelectedOnly"]),
            PreviewFingerprint: Convert.ToString(reader["PreviewFingerprint"]) ?? string.Empty,
            ApplyCount: Convert.ToInt32(reader["ApplyCount"]),
            AcceptedOnUtc: Convert.ToString(reader["AcceptedOnUtc"]) ?? string.Empty,
            AcceptedByUserId: Convert.ToInt32(reader["AcceptedByUserId"]),
            Message: Convert.ToString(reader["Message"]) ?? string.Empty);
    }

    private static async Task ExecuteApplyAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid runGuid,
        bool forceApply,
        bool applySelectedOnly,
        DriftSnapshot snapshot,
        CancellationToken cancellationToken)
    {
        await using var command = new SqlCommand("SMigration.MetadataApply_Run", connection, transaction)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 600
        };

        AddFingerprintParameters(command, runGuid, applySelectedOnly, snapshot);
        command.Parameters.Add(new SqlParameter("@ForceApply", SqlDbType.Bit) { Value = forceApply });

        await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    private static void AddFingerprintParameters(
        SqlCommand command,
        Guid runGuid,
        bool applySelectedOnly,
        DriftSnapshot snapshot)
    {
        command.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        command.Parameters.Add(new SqlParameter("@ApplySelectedOnly", SqlDbType.Bit) { Value = applySelectedOnly });
        command.Parameters.Add(new SqlParameter("@SourceSnapshotFingerprint", SqlDbType.VarChar, 64)
        {
            Value = snapshot.SourceFingerprint
        });
        command.Parameters.Add(new SqlParameter("@TargetSnapshotFingerprint", SqlDbType.VarChar, 64)
        {
            Value = snapshot.TargetFingerprint
        });
    }

    private static Dictionary<Guid, PayloadRow> BuildUniquePayloadIndex(
        IReadOnlyList<PayloadRow> rows,
        RegistryDefinition registry,
        string endpointName)
    {
        var duplicate = rows
            .GroupBy(row => row.RowGuid)
            .FirstOrDefault(group => group.Count() > 1);

        if (duplicate is not null)
        {
            throw Drift(registry, duplicate.Key, $"the {endpointName} contains duplicate Guid values");
        }

        return rows.ToDictionary(row => row.RowGuid);
    }

    private static void ValidateStoredPayloadHash(
        RegistryDefinition registry,
        Guid rowGuid,
        string endpointName,
        string payloadJson,
        byte[] expectedHash)
    {
        var actualHash = SHA256.HashData(Encoding.Unicode.GetBytes(payloadJson));
        if (!actualHash.AsSpan().SequenceEqual(expectedHash))
        {
            throw Drift(
                registry,
                rowGuid,
                $"the staged {endpointName} payload no longer matches its persisted SHA-256 hash");
        }
    }

    private static Guid ReadPayloadGuid(
        string payloadJson,
        string guidColumnName,
        Guid fallbackGuid)
    {
        using var document = JsonDocument.Parse(payloadJson);
        if (document.RootElement.ValueKind != JsonValueKind.Object)
        {
            return fallbackGuid;
        }

        foreach (var property in document.RootElement.EnumerateObject())
        {
            if ((property.Name.Equals(guidColumnName, StringComparison.OrdinalIgnoreCase)
                 || property.Name.Equals("Guid", StringComparison.OrdinalIgnoreCase))
                && property.Value.ValueKind == JsonValueKind.String
                && Guid.TryParse(property.Value.GetString(), out var targetGuid))
            {
                return targetGuid;
            }
        }

        return fallbackGuid;
    }

    private static bool PayloadsEquivalent(string expectedJson, string actualJson) =>
        string.Equals(CanonicalizeJson(expectedJson), CanonicalizeJson(actualJson), StringComparison.Ordinal);

    private static string CanonicalizeJson(string json)
    {
        using var document = JsonDocument.Parse(string.IsNullOrWhiteSpace(json) ? "{}" : json);
        var builder = new StringBuilder();
        AppendCanonicalJson(builder, document.RootElement);
        return builder.ToString();
    }

    private static void AppendCanonicalJson(StringBuilder builder, JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                builder.Append('{');
                foreach (var property in element.EnumerateObject().OrderBy(property => property.Name, StringComparer.Ordinal))
                {
                    AppendLengthPrefixed(builder, property.Name);
                    AppendCanonicalJson(builder, property.Value);
                }
                builder.Append('}');
                break;

            case JsonValueKind.Array:
                builder.Append('[');
                foreach (var item in element.EnumerateArray())
                {
                    AppendCanonicalJson(builder, item);
                }
                builder.Append(']');
                break;

            case JsonValueKind.String:
                builder.Append('s');
                AppendLengthPrefixed(builder, element.GetString() ?? string.Empty);
                break;

            case JsonValueKind.Number:
                builder.Append('n');
                AppendLengthPrefixed(builder, element.GetRawText());
                break;

            case JsonValueKind.True:
                builder.Append("true");
                break;

            case JsonValueKind.False:
                builder.Append("false");
                break;

            case JsonValueKind.Null:
            case JsonValueKind.Undefined:
                builder.Append("null");
                break;

            default:
                throw new InvalidOperationException($"Unsupported JSON value kind: {element.ValueKind}.");
        }
    }

    private static void AppendLengthPrefixed(StringBuilder builder, string value) =>
        builder.Append(value.Length).Append(':').Append(value);

    private static string BuildSnapshotRowEntry(RegistryDefinition registry, PayloadRow row)
    {
        var canonicalPayload = CanonicalizeJson(row.PayloadJson);
        var payloadHash = Convert.ToHexString(SHA256.HashData(Encoding.Unicode.GetBytes(canonicalPayload)));
        return $"row|{registry.ApplyOrder}|{registry.RegistryGuid:D}|{row.RowGuid:D}|{payloadHash}";
    }

    private static string ComputeAggregateFingerprint(IEnumerable<string> entries)
    {
        var envelope = string.Join("\n", entries.OrderBy(entry => entry, StringComparer.Ordinal));
        return Convert.ToHexString(SHA256.HashData(Encoding.Unicode.GetBytes(envelope)));
    }

    private static MetadataMigrationDriftException Drift(
        RegistryDefinition registry,
        Guid? sourceRowGuid,
        string reason)
    {
        var rowContext = sourceRowGuid.HasValue
            ? $" / {sourceRowGuid.Value:D}"
            : string.Empty;

        return new MetadataMigrationDriftException(
            $"Metadata migration drift detected for {registry.SchemaName}.{registry.TableName}{rowContext}: {reason}. Re-stage, validate, review and accept the current preview before deployment.");
    }

    private static void ValidateRunAndTargetArguments(
        Guid runGuid,
        string targetServerName,
        string targetDatabaseName)
    {
        if (runGuid == Guid.Empty)
        {
            throw new ArgumentException("A metadata migration run Guid is required.", nameof(runGuid));
        }

        if (string.IsNullOrWhiteSpace(targetServerName))
        {
            throw new ArgumentException("A target SQL Server name is required.", nameof(targetServerName));
        }

        if (string.IsNullOrWhiteSpace(targetDatabaseName))
        {
            throw new ArgumentException("A target database name is required.", nameof(targetDatabaseName));
        }
    }

    private static void ValidateRunEndpoints(
        RunDefinition run,
        string requestedTargetServerName,
        string requestedTargetDatabaseName)
    {
        if (!NormalizeServerName(run.TargetServerName).Equals(
                NormalizeServerName(requestedTargetServerName),
                StringComparison.Ordinal)
            || !run.TargetDatabaseName.Trim().Equals(
                requestedTargetDatabaseName.Trim(),
                StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "The requested metadata target does not match the server and database persisted on the run.");
        }

        if (NormalizeServerName(run.SourceServerName).Equals(
                NormalizeServerName(run.TargetServerName),
                StringComparison.Ordinal)
            && run.SourceDatabaseName.Trim().Equals(
                run.TargetDatabaseName.Trim(),
                StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Metadata migration source and target must be different databases.");
        }
    }

    private static string NormalizeServerName(string value) =>
        (value ?? string.Empty)
            .Trim()
            .Replace('/', '\\')
            .ToUpperInvariant();

    private static void ValidateFingerprint(string fingerprint, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(fingerprint)
            || fingerprint.Length != 64
            || !fingerprint.All(Uri.IsHexDigit))
        {
            throw new ArgumentException("A valid 64-character hexadecimal fingerprint is required.", parameterName);
        }
    }

    private static void ValidateSqlIdentifier(string identifier, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(identifier)
            || identifier.Length > 128
            || identifier.Any(character => !char.IsLetterOrDigit(character) && character != '_' && character != '#'))
        {
            throw new InvalidOperationException($"Unsafe metadata registry identifier in {parameterName}.");
        }
    }

    private static string QuoteName(string identifier) =>
        $"[{identifier.Replace("]", "]]", StringComparison.Ordinal)}]";

    private static async Task TryRollbackAsync(
        SqlTransaction transaction,
        CancellationToken cancellationToken)
    {
        try
        {
            await transaction.RollbackAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (InvalidOperationException)
        {
            // The transaction was already committed, rolled back, or disconnected.
        }
    }
}
