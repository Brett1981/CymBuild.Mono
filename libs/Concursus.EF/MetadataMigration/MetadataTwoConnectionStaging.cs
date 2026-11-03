using Microsoft.Data.SqlClient;
using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Concursus.EF.MetadataMigration;

/// <summary>
/// Metadata staging over two connections, for a source on a different SQL Server from the target.
/// SMigration.MetadataStage_Run and MetadataApplyIdentityMap_Build read the source by three-part
/// name, which only reaches a database on the same server. Moved unchanged from the API's
/// CoreService (CYB-584) so the Metadata Migration workbench and the headless metadata-auto
/// deploy (QA on 10.100.34.114 -> UAT on SOC-SQLBRE01) stage the same way.
/// </summary>
public static class MetadataTwoConnectionStaging
{
    /// <summary>A staging precondition failed (the API reports it as InvalidArgument).</summary>
    public sealed class MetadataStagingException(string message) : InvalidOperationException(message);

    public sealed class MetadataRegistryRow
    {
        public Guid RegistryGuid { get; init; }
        public string SchemaName { get; init; } = string.Empty;
        public string TableName { get; init; } = string.Empty;
        public string GuidColumnName { get; init; } = string.Empty;
        public string PrimaryKeyColumnName { get; init; } = string.Empty;
    }

    public sealed class MetadataPayloadRow
    {
        public Guid RowGuid { get; init; }
        public long? RowId { get; init; }
        public byte? RowStatus { get; init; }
        public string PayloadJson { get; init; } = "{}";
    }

    public sealed class OtherUniqueIndexColumnInfo
    {
        public string ColumnName { get; init; } = string.Empty;
        public string? ForeignKeyRefSchemaName { get; init; }
        public string? ForeignKeyRefTableName { get; init; }
    }

    public sealed class OtherUniqueIndexInfo
    {
        public string IndexName { get; init; } = string.Empty;
        public List<OtherUniqueIndexColumnInfo> Columns { get; init; } = new();

        // The index's WHERE clause (sys.indexes.filter_definition) when it is a filtered index,
        // e.g. "([IsDefaultValidation]=(1))". Only rows matching it are covered by the index.
        public string? FilterDefinition { get; init; }
    }

    public static async Task<List<OtherUniqueIndexInfo>> ReadOtherUniqueIndexesAsync(
        SqlConnection cn,
        string schemaName,
        string tableName,
        string guidColumnName,
        string primaryKeyColumnName,
        CancellationToken cancellationToken)
    {
        var indexes = new List<OtherUniqueIndexInfo>();

        await using var cmd = new SqlCommand(@"
;WITH IndexColumnCounts AS
(
    SELECT
        ic.object_id,
        ic.index_id,
        COUNT(*) AS ColumnCount,
        MIN(c.name) AS SoleColumnName
    FROM sys.index_columns AS ic
    INNER JOIN sys.columns AS c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    WHERE ic.is_included_column = 0
    GROUP BY ic.object_id, ic.index_id
)
SELECT
    i.index_id AS IndexId,
    i.name AS IndexName,
    CASE WHEN i.has_filter = 1 THEN i.filter_definition END AS FilterDefinition
FROM sys.indexes AS i
INNER JOIN sys.tables AS it
    ON it.object_id = i.object_id
INNER JOIN sys.schemas AS isch
    ON isch.schema_id = it.schema_id
INNER JOIN IndexColumnCounts AS icc
    ON icc.object_id = i.object_id
   AND icc.index_id = i.index_id
WHERE isch.name = @SchemaName
  AND it.name = @TableName
  AND i.is_unique = 1
  -- Exclude the identity Guid's own unique index and the table's surrogate primary key (an
  -- auto-increment ID is environment-specific; coincidentally matching another environment's
  -- row by number is meaningless, not a real natural-key collision). A foreign key column (e.g.
  -- GridDefinitionId) is no longer excluded here - the caller resolves it to the referenced
  -- row's Guid (via idToGuidByTable/targetIdToGuidByTable) when the referenced table is itself
  -- registered and enabled for this run, and only falls back to skipping the whole index when it
  -- references a table outside that set (see StageMetadataWithTwoConnectionsAsync).
  AND NOT (icc.ColumnCount = 1 AND icc.SoleColumnName IN (@GuidColumnName, @PrimaryKeyColumnName));", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = schemaName });
        cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = tableName });
        cmd.Parameters.Add(new SqlParameter("@GuidColumnName", SqlDbType.NVarChar, 128) { Value = guidColumnName });
        cmd.Parameters.Add(new SqlParameter("@PrimaryKeyColumnName", SqlDbType.NVarChar, 128) { Value = primaryKeyColumnName });

        var indexIds = new List<(int IndexId, string IndexName, string? FilterDefinition)>();
        await using (var reader = await cmd.ExecuteReaderAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                indexIds.Add((
                    Convert.ToInt32(reader["IndexId"]),
                    Convert.ToString(reader["IndexName"]) ?? string.Empty,
                    reader["FilterDefinition"] is DBNull ? null : Convert.ToString(reader["FilterDefinition"])));
            }
        }

        foreach (var (indexId, indexName, filterDefinition) in indexIds)
        {
            await using var colCmd = new SqlCommand(@"
SELECT
    c.name AS ColumnName,
    rs.name AS RefSchemaName,
    rt.name AS RefTableName
FROM sys.index_columns AS ic
INNER JOIN sys.columns AS c
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
LEFT JOIN sys.foreign_key_columns AS fkc
    ON fkc.parent_object_id = ic.object_id
   AND fkc.parent_column_id = ic.column_id
   AND c.name <> N'RowStatus'
LEFT JOIN sys.tables AS rt
    ON rt.object_id = fkc.referenced_object_id
LEFT JOIN sys.schemas AS rs
    ON rs.schema_id = rt.schema_id
WHERE ic.object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName))
  AND ic.index_id = @IndexId
  AND ic.is_included_column = 0
ORDER BY ic.key_ordinal;", cn)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 300
            };
            colCmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = schemaName });
            colCmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = tableName });
            colCmd.Parameters.Add(new SqlParameter("@IndexId", SqlDbType.Int) { Value = indexId });

            var columns = new List<OtherUniqueIndexColumnInfo>();
            await using (var colReader = await colCmd.ExecuteReaderAsync(cancellationToken))
            {
                while (await colReader.ReadAsync(cancellationToken))
                {
                    columns.Add(new OtherUniqueIndexColumnInfo
                    {
                        ColumnName = Convert.ToString(colReader["ColumnName"]) ?? string.Empty,
                        ForeignKeyRefSchemaName = colReader["RefSchemaName"] is DBNull ? null : Convert.ToString(colReader["RefSchemaName"]),
                        ForeignKeyRefTableName = colReader["RefTableName"] is DBNull ? null : Convert.ToString(colReader["RefTableName"])
                    });
                }
            }

            if (columns.Count > 0)
            {
                indexes.Add(new OtherUniqueIndexInfo { IndexName = indexName, Columns = columns, FilterDefinition = filterDefinition });
            }
        }

        return indexes;
    }

    // CYB-564: a filtered unique index only constrains the rows its WHERE clause selects. Returns
    // the Guids of the rows on this connection's copy of the table that the filter covers. The
    // filter text is read from the target's own catalog (sys.indexes), never from user input, and
    // is evaluated against the source copy too - the question being "would this row, once applied,
    // fall under the target's index?". Every target column is already confirmed present in the
    // source before this runs.
    public static async Task<HashSet<Guid>> ReadGuidsCoveredByIndexFilterAsync(
        SqlConnection cn,
        MetadataRegistryRow registry,
        string filterDefinition,
        CancellationToken cancellationToken)
    {
        var guids = new HashSet<Guid>();

        await using var cmd = new SqlCommand($@"
SELECT CONVERT(UNIQUEIDENTIFIER, s.{QuoteName(registry.GuidColumnName)}) AS RowGuid
FROM {QuoteName(registry.SchemaName)}.{QuoteName(registry.TableName)} AS s
WHERE {filterDefinition};", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            if (reader["RowGuid"] is Guid rowGuid)
            {
                guids.Add(rowGuid);
            }
        }

        return guids;
    }

    public sealed class ForeignKeyToRegisteredTableInfo
    {
        public string ChildColumnName { get; init; } = string.Empty;
        public string RefSchemaName { get; init; } = string.Empty;
        public string RefTableName { get; init; } = string.Empty;
    }

    public static async Task<List<ForeignKeyToRegisteredTableInfo>> ReadForeignKeysToRegisteredTablesAsync(
        SqlConnection cn,
        string schemaName,
        string tableName,
        CancellationToken cancellationToken)
    {
        var results = new List<ForeignKeyToRegisteredTableInfo>();

        await using var cmd = new SqlCommand(@"
SELECT
    pc.name AS ChildColumnName,
    rs.name AS RefSchemaName,
    rt.name AS RefTableName
FROM sys.foreign_key_columns AS fkc
INNER JOIN sys.columns AS pc
    ON pc.object_id = fkc.parent_object_id
   AND pc.column_id = fkc.parent_column_id
INNER JOIN sys.tables AS rt
    ON rt.object_id = fkc.referenced_object_id
INNER JOIN sys.schemas AS rs
    ON rs.schema_id = rt.schema_id
WHERE fkc.parent_object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName))
  AND pc.name <> N'RowStatus'
  AND NOT (rs.name = @SchemaName AND rt.name = @TableName)
  AND EXISTS
  (
      SELECT 1
      FROM SMigration.Metadata_TableRegistry AS refTr
      WHERE refTr.SchemaName = rs.name
        AND refTr.TableName = rt.name
        AND refTr.RowStatus NOT IN (0,254)
        AND refTr.IsEnabled = 1
  );", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = schemaName });
        cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = tableName });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            results.Add(new ForeignKeyToRegisteredTableInfo
            {
                ChildColumnName = Convert.ToString(reader["ChildColumnName"]) ?? string.Empty,
                RefSchemaName = Convert.ToString(reader["RefSchemaName"]) ?? string.Empty,
                RefTableName = Convert.ToString(reader["RefTableName"]) ?? string.Empty
            });
        }

        return results;
    }

    // A composite unique index can include a foreign key column (e.g. GridDefinitionId on
    // SUserInterface.GridViewDefinitions' GridDefinitionId+Code+RowStatus key). The raw ID it
    // holds is a per-environment auto-increment surrogate, not comparable across source and
    // target directly - so instead of comparing it raw (or skipping the whole index, hiding a
    // real collision until it fails as a raw SQL error at Apply), resolve it to the referenced
    // row's Guid via idToGuidByTable (the source-side map when building a source row's key, the
    // target-side map when building a target row's key) and compare Guids. If the referenced row
    // cannot be resolved (unparseable ID, or not found - e.g. the referenced table is not itself
    // registered/enabled for this run), the key is null so this row is simply excluded from this
    // particular collision check, the same conservative fallback as a missing scalar column.
    public static string? BuildNaturalKeyWithForeignKeyResolution(
        Dictionary<string, string> values,
        IReadOnlyList<OtherUniqueIndexColumnInfo> columns,
        IReadOnlyDictionary<string, Dictionary<long, Guid>> idToGuidByTable)
    {
        var parts = new List<string>(columns.Count);
        foreach (var column in columns)
        {
            if (!values.TryGetValue(column.ColumnName, out var rawValue) || string.IsNullOrEmpty(rawValue))
            {
                return null;
            }

            if (column.ForeignKeyRefTableName is null)
            {
                parts.Add(rawValue);
                continue;
            }

            var refTableKey = $"{column.ForeignKeyRefSchemaName}.{column.ForeignKeyRefTableName}";
            if (!long.TryParse(rawValue, out var referencedId) ||
                !idToGuidByTable.TryGetValue(refTableKey, out var refIdToGuid) ||
                !refIdToGuid.TryGetValue(referencedId, out var referencedGuid))
            {
                return null;
            }

            parts.Add(referencedGuid.ToString("D"));
        }

        return string.Join("", parts);
    }

    public static async Task StageMetadataWithTwoConnectionsAsync(
    SqlConnection sourceConnection,
    SqlConnection targetConnection,
    Guid runGuid,
    bool includeRetirements,
    CancellationToken cancellationToken)
    {
        await SyncMetadataRegistryFromEntityTypesAsync(
            sourceConnection,
            targetConnection,
            runGuid,
            cancellationToken);

        var registryRows = await ReadMetadataRegistryAsync(
            targetConnection,
            null,
            cancellationToken);

        if (registryRows.Count == 0)
        {
            throw new MetadataStagingException("No enabled metadata registry rows exist. Run SMigration.MetadataRegistry_Seed first.");
        }

        var stagedRows = new List<(Guid RegistryGuid, MetadataPayloadRow SourceRow, byte[] SourceHash, string? TargetPayloadJson, byte[]? TargetHash, string DifferenceType)>();
        var validationIssues = new List<(Guid? RegistryGuid, Guid? SourceRowGuid, string Severity, string IssueCode, string IssueMessage, string DetailsJson)>();

        // Registries are processed in ApplyOrder (the same dependency order Apply itself relies
        // on), so by the time a child table is reached here, every parent table it could
        // reference has already recorded its own exclusions below - accumulate both maps as we
        // go so a child's foreign key can be resolved to its parent's Guid, and checked against
        // that parent's own exclusions, transitively across as many levels as needed. The same
        // ordering guarantee also lets a child table's own composite unique-key check resolve a
        // foreign key column to its parent's Guid on both the source side (idToGuidByTable) and
        // the target side (targetIdToGuidByTable) - see BuildNaturalKeyWithForeignKeyResolution.
        var idToGuidByTable = new Dictionary<string, Dictionary<long, Guid>>(StringComparer.OrdinalIgnoreCase);
        var targetIdToGuidByTable = new Dictionary<string, Dictionary<long, Guid>>(StringComparer.OrdinalIgnoreCase);
        var excludedGuidsByTable = new Dictionary<string, HashSet<Guid>>(StringComparer.OrdinalIgnoreCase);

        // A foreign key column in a composite unique index is only resolvable via Guid when the
        // table it references is itself registered and enabled for this run (idToGuidByTable/
        // targetIdToGuidByTable are only ever populated for those tables). A foreign key to any
        // other table (e.g. SUserInterface.WidgetTypes, which is registered but currently
        // disabled) is left exactly as unresolvable as before - the whole index is skipped rather
        // than guessing that its raw ID is safe to compare across environments.
        var enabledRegistryTableKeys = new HashSet<string>(
            registryRows.Select(r => $"{r.SchemaName}.{r.TableName}"),
            StringComparer.OrdinalIgnoreCase);

        foreach (var registry in registryRows)
        {
            if (!IsSafeSqlIdentifier(registry.SchemaName) ||
                !IsSafeSqlIdentifier(registry.TableName) ||
                !IsSafeSqlIdentifier(registry.GuidColumnName) ||
                !IsSafeSqlIdentifier(registry.PrimaryKeyColumnName))
            {
                validationIssues.Add((
                    registry.RegistryGuid,
                    null,
                    "Fail",
                    "InvalidRegistryIdentifier",
                    $"Registry contains an unsafe SQL identifier: {registry.SchemaName}.{registry.TableName}.",
                    JsonSerializer.Serialize(new { registry.SchemaName, registry.TableName, registry.GuidColumnName, registry.PrimaryKeyColumnName })));
                continue;
            }

            if (!await TableExistsAsync(targetConnection, null, registry.SchemaName, registry.TableName, cancellationToken))
            {
                validationIssues.Add((
                    registry.RegistryGuid,
                    null,
                    "Fail",
                    "RegisteredTableMissing",
                    $"Registered metadata table does not exist in target: {registry.SchemaName}.{registry.TableName}.",
                    JsonSerializer.Serialize(new { registry.SchemaName, registry.TableName })));
                continue;
            }

            if (!await TableExistsAsync(sourceConnection, null, registry.SchemaName, registry.TableName, cancellationToken))
            {
                validationIssues.Add((
                    registry.RegistryGuid,
                    null,
                    "Fail",
                    "RegisteredSourceTableMissing",
                    $"Registered metadata table does not exist in source: {registry.SchemaName}.{registry.TableName}.",
                    JsonSerializer.Serialize(new { registry.SchemaName, registry.TableName })));
                continue;
            }

            if (!await ColumnExistsAsync(targetConnection, null, registry.SchemaName, registry.TableName, registry.GuidColumnName, cancellationToken))
            {
                validationIssues.Add((
                    registry.RegistryGuid,
                    null,
                    "Fail",
                    "RegisteredGuidColumnMissing",
                    $"Registered metadata table does not have Guid column in target: {registry.SchemaName}.{registry.TableName}.{registry.GuidColumnName}.",
                    JsonSerializer.Serialize(new { registry.SchemaName, registry.TableName, registry.GuidColumnName })));
                continue;
            }

            if (!await ColumnExistsAsync(sourceConnection, null, registry.SchemaName, registry.TableName, registry.GuidColumnName, cancellationToken))
            {
                validationIssues.Add((
                    registry.RegistryGuid,
                    null,
                    "Fail",
                    "RegisteredSourceGuidColumnMissing",
                    $"Registered metadata table does not have Guid column in source: {registry.SchemaName}.{registry.TableName}.{registry.GuidColumnName}.",
                    JsonSerializer.Serialize(new { registry.SchemaName, registry.TableName, registry.GuidColumnName })));
                continue;
            }

            var columnNames = await ReadStageColumnNamesAsync(targetConnection, null, registry.SchemaName, registry.TableName, cancellationToken);
            if (columnNames.Count == 0)
            {
                continue;
            }

            var sourceColumnNames = await ReadStageColumnNamesAsync(sourceConnection, null, registry.SchemaName, registry.TableName, cancellationToken);
            var missingColumns = columnNames
                .Where(column => !sourceColumnNames.Contains(column, StringComparer.OrdinalIgnoreCase))
                .ToList();

            if (missingColumns.Count > 0)
            {
                validationIssues.Add((
                    registry.RegistryGuid,
                    null,
                    "Fail",
                    "RegisteredSourceColumnMissing",
                    $"Source metadata table is missing one or more target metadata columns: {registry.SchemaName}.{registry.TableName}.",
                    JsonSerializer.Serialize(new { registry.SchemaName, registry.TableName, MissingColumns = missingColumns })));
                continue;
            }

            var sourceRows = await ReadMetadataPayloadRowsAsync(sourceConnection, null, registry, columnNames, true, cancellationToken);
            var targetRows = await ReadMetadataPayloadRowsAsync(targetConnection, null, registry, columnNames, false, cancellationToken);

            // CYB-564: opt-in retirement. A source row soft-deleted to 254 is staged (as an Update
            // carrying RowStatus 254) only when the target still holds an active row with the same
            // Guid - rows that exist only in the target are never touched. These rows are kept out
            // of sourceRows so duplicate-Guid and natural-key checks stay active-only, exactly as
            // SMigration.MetadataStage_Run does with @IncludeRetirements.
            var retiredSourceRows = includeRetirements
                ? await ReadMetadataPayloadRowsAsync(sourceConnection, null, registry, columnNames, false, cancellationToken, retiredOnly: true)
                : new List<MetadataPayloadRow>();

            var duplicateGroups = sourceRows
                .GroupBy(row => row.RowGuid)
                .Where(group => group.Count() > 1)
                .ToList();

            var duplicateGuids = duplicateGroups.Select(group => group.Key).ToHashSet();

            foreach (var duplicateGroup in duplicateGroups)
            {
                validationIssues.Add((
                    registry.RegistryGuid,
                    duplicateGroup.Key,
                    "Fail",
                    "DuplicateSourceGuid",
                    $"Source metadata table contains duplicate active Guid values: {registry.SchemaName}.{registry.TableName} / {duplicateGroup.Key}.",
                    JsonSerializer.Serialize(new { registry.SchemaName, registry.TableName, DuplicateCount = duplicateGroup.Count() })));
            }

            var targetByGuid = targetRows
                .GroupBy(row => row.RowGuid)
                .ToDictionary(group => group.Key, group => group.First());

            var retireCandidateRows = retiredSourceRows
                .Where(row =>
                    targetByGuid.TryGetValue(row.RowGuid, out var targetRow) &&
                    targetRow.RowStatus is not null and not 0 and not 254)
                .ToList();

            // A registered table can enforce uniqueness on more than its identity Guid (e.g. a
            // Name+RowStatus natural key on SCore.EntityTypes). Two environments can independently
            // create a row with the same natural-key value under two different Guids; applying the
            // source row would then fail with a raw unique-constraint violation at Apply instead of
            // a reviewable, ignorable issue surfaced before Apply is ever attempted. The same-server
            // SQL path (SMigration.MetadataStage_Run) already detects this via a three-part cross-
            // database join, which cannot reach a genuinely cross-server source at all - this is
            // the C# equivalent for this (two-connection) path.
            var otherUniqueIndexes = await ReadOtherUniqueIndexesAsync(
                targetConnection,
                registry.SchemaName,
                registry.TableName,
                registry.GuidColumnName,
                registry.PrimaryKeyColumnName,
                cancellationToken);

            var duplicateTargetKeySourceGuids = new HashSet<Guid>();

            foreach (var index in otherUniqueIndexes)
            {
                // A foreign key column is only checkable when the table it references is itself
                // registered/enabled (its rows have a resolvable Guid in idToGuidByTable /
                // targetIdToGuidByTable). If any column in this index references a table outside
                // that set, this index cannot be safely evaluated at all - skip it exactly as the
                // old blanket "any FK column disqualifies the index" rule did for that case.
                if (index.Columns.Any(column =>
                    column.ForeignKeyRefTableName is not null &&
                    !enabledRegistryTableKeys.Contains($"{column.ForeignKeyRefSchemaName}.{column.ForeignKeyRefTableName}")))
                {
                    continue;
                }

                // CYB-564: a filtered index (e.g. IX_UQ_EntityQueries_EntityHobtID_IsDefaultValidation,
                // WHERE IsDefaultValidation = 1) never constrains rows outside its filter. Ignoring the
                // filter falsely flagged SSop.QuotesUpsert (IsDefaultValidation = 0) as a
                // DuplicateTargetKey on UAT and silently excluded it from the run; it also let retired
                // target rows collide under RowStatus-filtered indexes.
                HashSet<Guid>? targetCoveredGuids = null;
                HashSet<Guid>? sourceCoveredGuids = null;
                if (!string.IsNullOrWhiteSpace(index.FilterDefinition))
                {
                    targetCoveredGuids = await ReadGuidsCoveredByIndexFilterAsync(targetConnection, registry, index.FilterDefinition, cancellationToken);
                    sourceCoveredGuids = await ReadGuidsCoveredByIndexFilterAsync(sourceConnection, registry, index.FilterDefinition, cancellationToken);
                }

                var targetKeyToGuid = new Dictionary<string, Guid>(StringComparer.OrdinalIgnoreCase);
                foreach (var targetRow in targetRows.Where(row => targetCoveredGuids is null || targetCoveredGuids.Contains(row.RowGuid)))
                {
                    var key = BuildNaturalKeyWithForeignKeyResolution(ParseJsonDictionary(targetRow.PayloadJson), index.Columns, targetIdToGuidByTable);
                    if (key is not null && !targetKeyToGuid.ContainsKey(key))
                    {
                        targetKeyToGuid[key] = targetRow.RowGuid;
                    }
                }

                foreach (var sourceRow in sourceRows.Where(row =>
                    !duplicateGuids.Contains(row.RowGuid) &&
                    (sourceCoveredGuids is null || sourceCoveredGuids.Contains(row.RowGuid))))
                {
                    var key = BuildNaturalKeyWithForeignKeyResolution(ParseJsonDictionary(sourceRow.PayloadJson), index.Columns, idToGuidByTable);
                    if (key is null)
                    {
                        continue;
                    }

                    if (targetKeyToGuid.TryGetValue(key, out var conflictingTargetGuid) && conflictingTargetGuid != sourceRow.RowGuid)
                    {
                        duplicateTargetKeySourceGuids.Add(sourceRow.RowGuid);
                        validationIssues.Add((
                            registry.RegistryGuid,
                            sourceRow.RowGuid,
                            "Warn",
                            "DuplicateTargetKey",
                            $"Target unique key ({index.IndexName}) on {registry.SchemaName}.{registry.TableName} already has a different row with the same value: {sourceRow.RowGuid}.",
                            JsonSerializer.Serialize(new
                            {
                                registry.SchemaName,
                                registry.TableName,
                                IndexName = index.IndexName,
                                Columns = string.Join(",", index.Columns.Select(c => c.ColumnName)),
                                ConflictingTargetGuid = conflictingTargetGuid
                            })));
                    }
                }
            }

            // Excluding a conflicting row (duplicate Guid/key) is correct, but any other registered
            // table that references it by foreign key would otherwise silently try to apply an
            // orphaned reference (its lookup resolves to nothing, e.g. a NULL foreign key or, as
            // seen live, "could not resolve EntityHoBT source ID 205" at Apply time). Cascade the
            // exclusion through this table's own foreign keys into other registered tables.
            var foreignKeys = await ReadForeignKeysToRegisteredTablesAsync(
                targetConnection,
                registry.SchemaName,
                registry.TableName,
                cancellationToken);

            var unresolvedReferenceSourceGuids = new HashSet<Guid>();

            if (foreignKeys.Count > 0)
            {
                foreach (var sourceRow in sourceRows
                    .Where(row => !duplicateGuids.Contains(row.RowGuid) && !duplicateTargetKeySourceGuids.Contains(row.RowGuid))
                    .Concat(retireCandidateRows))
                {
                    var sourceValues = ParseJsonDictionary(sourceRow.PayloadJson);

                    foreach (var foreignKey in foreignKeys)
                    {
                        if (!sourceValues.TryGetValue(foreignKey.ChildColumnName, out var rawValue) ||
                            !long.TryParse(rawValue, out var referencedId))
                        {
                            continue;
                        }

                        var refTableKey = $"{foreignKey.RefSchemaName}.{foreignKey.RefTableName}";
                        if (!idToGuidByTable.TryGetValue(refTableKey, out var refIdToGuid) ||
                            !refIdToGuid.TryGetValue(referencedId, out var referencedGuid))
                        {
                            continue;
                        }

                        if (excludedGuidsByTable.TryGetValue(refTableKey, out var refExcluded) &&
                            refExcluded.Contains(referencedGuid))
                        {
                            unresolvedReferenceSourceGuids.Add(sourceRow.RowGuid);
                            validationIssues.Add((
                                registry.RegistryGuid,
                                sourceRow.RowGuid,
                                "Warn",
                                "UnresolvedReference",
                                $"Row in {registry.SchemaName}.{registry.TableName} references {foreignKey.RefSchemaName}.{foreignKey.RefTableName} Guid {referencedGuid} which is excluded from this run and needs manual correction upstream first: {sourceRow.RowGuid}.",
                                JsonSerializer.Serialize(new
                                {
                                    registry.SchemaName,
                                    registry.TableName,
                                    ForeignKeyColumn = foreignKey.ChildColumnName,
                                    ReferencedSchemaName = foreignKey.RefSchemaName,
                                    ReferencedTableName = foreignKey.RefTableName,
                                    ReferencedGuid = referencedGuid
                                })));
                            break;
                        }
                    }
                }
            }

            foreach (var sourceRow in sourceRows
                .Where(row =>
                    !duplicateGuids.Contains(row.RowGuid) &&
                    !duplicateTargetKeySourceGuids.Contains(row.RowGuid) &&
                    !unresolvedReferenceSourceGuids.Contains(row.RowGuid))
                .Concat(retireCandidateRows.Where(row => !unresolvedReferenceSourceGuids.Contains(row.RowGuid))))
            {
                targetByGuid.TryGetValue(sourceRow.RowGuid, out var targetRow);

                var sourceHash = ComputeSha256(sourceRow.PayloadJson);
                var targetHash = targetRow is null ? null : ComputeSha256(targetRow.PayloadJson);

                var differenceType = targetRow is null
                    ? "Insert"
                    : sourceHash.SequenceEqual(targetHash!)
                        ? "NoChange"
                        : "Update";

                stagedRows.Add((
                    registry.RegistryGuid,
                    sourceRow,
                    sourceHash,
                    targetRow?.PayloadJson,
                    targetHash,
                    differenceType));
            }

            var tableKey = $"{registry.SchemaName}.{registry.TableName}";
            var idToGuidMap = new Dictionary<long, Guid>();
            foreach (var sourceRow in sourceRows.Concat(retiredSourceRows))
            {
                if (sourceRow.RowId.HasValue)
                {
                    idToGuidMap[sourceRow.RowId.Value] = sourceRow.RowGuid;
                }
            }

            var targetIdToGuidMap = new Dictionary<long, Guid>();
            foreach (var targetRow in targetRows)
            {
                if (targetRow.RowId.HasValue)
                {
                    targetIdToGuidMap[targetRow.RowId.Value] = targetRow.RowGuid;
                }
            }

            idToGuidByTable[tableKey] = idToGuidMap;
            targetIdToGuidByTable[tableKey] = targetIdToGuidMap;
            excludedGuidsByTable[tableKey] = new HashSet<Guid>(duplicateGuids
                .Concat(duplicateTargetKeySourceGuids)
                .Concat(unresolvedReferenceSourceGuids));
        }

        await using var txBase = await targetConnection.BeginTransactionAsync(cancellationToken);
        var tx = (SqlTransaction)txBase;

        try
        {
            await ExecuteTargetNonQueryAsync(
                targetConnection,
                tx,
                """
            DELETE FROM SMigration.Metadata_StagedRows
            WHERE RunGuid = @RunGuid;

            DELETE FROM SMigration.Metadata_ValidationIssues
            WHERE RunGuid = @RunGuid
              AND IssueCode IN
              (
                  N'DuplicateSourceGuid',
                  N'DuplicateTargetKey',
                  N'UnresolvedReference',
                  N'RegisteredGuidColumnMissing',
                  N'RegisteredSourceGuidColumnMissing',
                  N'RegisteredTableMissing',
                  N'RegisteredSourceTableMissing',
                  N'RegisteredSourceColumnMissing',
                  N'InvalidRegistryIdentifier'
              );
            """,
                runGuid,
                cancellationToken);

            foreach (var issue in validationIssues)
            {
                await AddValidationIssueAsync(
                    targetConnection,
                    tx,
                    runGuid,
                    issue.RegistryGuid,
                    issue.SourceRowGuid,
                    issue.Severity,
                    issue.IssueCode,
                    issue.IssueMessage,
                    issue.DetailsJson,
                    cancellationToken);
            }

            // Bulk-copy rather than one INSERT per row: a full baseline run against a fresh
            // environment pair can stage tens of thousands of rows (NoChange included), and a
            // per-row round trip over a cross-server connection is what actually consumed most of
            // the several minutes this used to take - the "SqlTransaction has completed" error
            // seen at ~5 minutes was this loop (or the ambient transaction it ran under) running
            // into trouble, not the much cheaper set-based normalisation step that runs after it.
            await BulkInsertStagedRowsAsync(targetConnection, tx, runGuid, stagedRows, cancellationToken);

            await ExecuteTargetNonQueryAsync(
            targetConnection,
            tx,
            """
            EXEC SMigration.MetadataStage_NormaliseDifferences
                @RunGuid = @RunGuid;
            """,
            runGuid,
            cancellationToken);

            await UpdateStageRunSummaryAsync(targetConnection, tx, runGuid, cancellationToken);

            await AddExecutionLogAsync(
                targetConnection,
                tx,
                runGuid,
                "StageRun",
                "Succeeded",
                $"Metadata staging completed using API two-connection staging. Rows staged: {stagedRows.Count}.",
                "{}",
                cancellationToken);

            await tx.CommitAsync(cancellationToken);
        }
        catch
        {
            // The transaction may already be dead server-side (e.g. a stored proc under
            // SET XACT_ABORT ON auto-rolled back after a timeout or error). Rolling back an
            // already-completed SqlTransaction throws "This SqlTransaction has completed; it is
            // no longer usable" - swallow that secondary failure so the real, original exception
            // (the one actually worth seeing) reaches the caller instead of being masked by it.
            try
            {
                await tx.RollbackAsync(cancellationToken);
            }
            catch
            {
            }

            throw;
        }
    }

    public sealed class MetadataRegistryCandidate
    {
        public string SchemaName { get; init; } = string.Empty;
        public string TableName { get; init; } = string.Empty;
        public bool IsMetaData { get; init; }
    }

    public static async Task SyncMetadataRegistryFromEntityTypesAsync(
        SqlConnection sourceConnection,
        SqlConnection targetConnection,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        // Source EntityTypes are authoritative for registry scope, matching
        // SMigration.MetadataRegistry_SyncFromEntityTypes (the same-server T-SQL path) and
        // SMigration.MetadataApplyIdentityMap_Build (which always passes the run's own source
        // database rather than falling back to target). The previous implementation unioned
        // candidates from BOTH source and target and only ever enabled registry rows, never
        // disabled one - so a table the target environment had independently (and wrongly)
        // flagged IsMetaData = 1 stayed enabled forever, regardless of the source's own flag.
        var candidates = (await ReadMetadataRegistryCandidatesAsync(sourceConnection, cancellationToken))
            .Where(candidate => !string.IsNullOrWhiteSpace(candidate.SchemaName) && !string.IsNullOrWhiteSpace(candidate.TableName))
            .GroupBy(candidate => $"{candidate.SchemaName}.{candidate.TableName}", StringComparer.OrdinalIgnoreCase)
            .Select(group => new MetadataRegistryCandidate
            {
                SchemaName = group.First().SchemaName,
                TableName = group.First().TableName,
                IsMetaData = group.Any(candidate => candidate.IsMetaData)
            })
            .OrderBy(candidate => candidate.SchemaName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(candidate => candidate.TableName, StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (candidates.Count == 0)
        {
            return;
        }

        await using var txBase = await targetConnection.BeginTransactionAsync(cancellationToken);
        var tx = (SqlTransaction)txBase;

        var enabledCount = 0;
        var disabledCount = 0;
        var skippedCount = 0;

        try
        {
            foreach (var candidate in candidates)
            {
                if (!IsSafeSqlIdentifier(candidate.SchemaName) || !IsSafeSqlIdentifier(candidate.TableName))
                {
                    skippedCount++;
                    continue;
                }

                if (candidate.IsMetaData)
                {
                    await UpsertMetadataRegistryCandidateAsync(targetConnection, tx, candidate, cancellationToken);
                    enabledCount++;
                }
                else
                {
                    await DisableMetadataRegistryCandidateAsync(targetConnection, tx, candidate, cancellationToken);
                    disabledCount++;
                }
            }

            await AddExecutionLogAsync(
                targetConnection,
                tx,
                runGuid,
                "RegistrySync",
                "Succeeded",
                $"Metadata registry synced from source IsMetaData EntityTypes. Enabled: {enabledCount}; disabled: {disabledCount}; skipped unsafe: {skippedCount}.",
                JsonSerializer.Serialize(new { enabledCount, disabledCount, skippedCount }),
                cancellationToken);

            await tx.CommitAsync(cancellationToken);
        }
        catch
        {
            // The transaction may already be dead server-side (e.g. a stored proc under
            // SET XACT_ABORT ON auto-rolled back after a timeout or error). Rolling back an
            // already-completed SqlTransaction throws "This SqlTransaction has completed; it is
            // no longer usable" - swallow that secondary failure so the real, original exception
            // (the one actually worth seeing) reaches the caller instead of being masked by it.
            try
            {
                await tx.RollbackAsync(cancellationToken);
            }
            catch
            {
            }

            throw;
        }
    }

    public static async Task<List<MetadataRegistryCandidate>> ReadMetadataRegistryCandidatesAsync(
        SqlConnection cn,
        CancellationToken cancellationToken)
    {
        var rows = new List<MetadataRegistryCandidate>();

        await using var cmd = new SqlCommand(@"
SELECT DISTINCT
    CONVERT(NVARCHAR(128), eh.SchemaName) AS SchemaName,
    CONVERT(NVARCHAR(128), eh.ObjectName) AS TableName,
    CONVERT(BIT, ISNULL(et.IsMetaData, 0)) AS IsMetaData
FROM SCore.EntityTypes AS et
INNER JOIN SCore.EntityHobts AS eh
    ON eh.EntityTypeID = et.ID
   AND eh.RowStatus NOT IN (0,254)
WHERE et.RowStatus NOT IN (0,254)
  AND ISNULL(eh.IsMainHoBT, 0) = 1
  AND NULLIF(eh.SchemaName, N'') IS NOT NULL
  AND NULLIF(eh.ObjectName, N'') IS NOT NULL
ORDER BY
    SchemaName,
    TableName;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            rows.Add(new MetadataRegistryCandidate
            {
                SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                TableName = Convert.ToString(reader["TableName"]) ?? string.Empty,
                IsMetaData = Convert.ToBoolean(reader["IsMetaData"])
            });
        }

        return rows;
    }

    public static async Task DisableMetadataRegistryCandidateAsync(
        SqlConnection cn,
        SqlTransaction tx,
        MetadataRegistryCandidate candidate,
        CancellationToken cancellationToken)
    {
        // Only disables a registry row that already exists and is enabled - never inserts a new,
        // disabled placeholder row. This mirrors MetadataRegistry_SyncFromEntityTypes.sql's own
        // disable UPDATE, which likewise only touches existing enabled rows and leaves curated
        // registry rows that aren't backed by a controllable EntityType untouched.
        await using var cmd = new SqlCommand(@"
UPDATE SMigration.Metadata_TableRegistry
SET IsEnabled = 0
WHERE SchemaName = @SchemaName
  AND TableName = @TableName
  AND RowStatus NOT IN (0,254)
  AND IsEnabled = 1;", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = candidate.SchemaName });
        cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = candidate.TableName });

        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public static async Task UpsertMetadataRegistryCandidateAsync(
        SqlConnection cn,
        SqlTransaction tx,
        MetadataRegistryCandidate candidate,
        CancellationToken cancellationToken)
    {
        var registryGuid = CreateStableMetadataRegistryGuid(candidate.SchemaName, candidate.TableName);
        var applyOrder = GetStableMetadataRegistryApplyOrder(candidate.SchemaName, candidate.TableName);

        await using var cmd = new SqlCommand(@"
DECLARE @EffectiveGuid UNIQUEIDENTIFIER = NULL;

SELECT TOP (1)
    @EffectiveGuid = tr.Guid
FROM SMigration.Metadata_TableRegistry AS tr
WHERE tr.SchemaName = @SchemaName
  AND tr.TableName = @TableName
ORDER BY
    CASE WHEN tr.RowStatus NOT IN (0,254) THEN 0 ELSE 1 END,
    tr.ID DESC;

IF @EffectiveGuid IS NULL
BEGIN
    SET @EffectiveGuid = @RegistryGuid;

    EXEC SMigration.MetadataDataObject_Ensure
        @Guid = @EffectiveGuid,
        @SchemeName = N'SMigration',
        @ObjectName = N'Metadata_TableRegistry';

    INSERT INTO SMigration.Metadata_TableRegistry
    (
        Guid,
        RowStatus,
        SchemaName,
        TableName,
        GuidColumnName,
        PrimaryKeyColumnName,
        ApplyOrder,
        IsEnabled,
        IsDataObjectBacked,
        IsRetirable,
        IsEnvironmentSpecific,
        NaturalKeyJson,
        ParentDependencyJson,
        CreatedOnUtc
    )
    SELECT
        @EffectiveGuid,
        1,
        @SchemaName,
        @TableName,
        N'Guid',
        N'ID',
        @ApplyOrder,
        1,
        1,
        1,
        0,
        N'[]',
        N'[]',
        SYSUTCDATETIME()
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_TableRegistry AS tr
        WHERE tr.SchemaName = @SchemaName
          AND tr.TableName = @TableName
    );
END
ELSE
BEGIN
    EXEC SMigration.MetadataDataObject_Ensure
        @Guid = @EffectiveGuid,
        @SchemeName = N'SMigration',
        @ObjectName = N'Metadata_TableRegistry';

    UPDATE SMigration.Metadata_TableRegistry
    SET
        RowStatus = 1,
        IsEnabled = 1,
        GuidColumnName = CASE WHEN NULLIF(GuidColumnName, N'') IS NULL THEN N'Guid' ELSE GuidColumnName END,
        PrimaryKeyColumnName = CASE WHEN NULLIF(PrimaryKeyColumnName, N'') IS NULL THEN N'ID' ELSE PrimaryKeyColumnName END
    WHERE Guid = @EffectiveGuid;
END;", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RegistryGuid", SqlDbType.UniqueIdentifier) { Value = registryGuid });
        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = candidate.SchemaName });
        cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = candidate.TableName });
        cmd.Parameters.Add(new SqlParameter("@ApplyOrder", SqlDbType.Int) { Value = applyOrder });

        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public static Guid CreateStableMetadataRegistryGuid(string schemaName, string tableName)
    {
        using var sha256 = SHA256.Create();
        var input = Encoding.UTF8.GetBytes($"SMigration.Metadata_TableRegistry|{schemaName}.{tableName}".ToUpperInvariant());
        var hash = sha256.ComputeHash(input);
        var guidBytes = hash.Take(16).ToArray();
        return new Guid(guidBytes);
    }

    public static int GetStableMetadataRegistryApplyOrder(string schemaName, string tableName)
    {
        using var sha256 = SHA256.Create();
        var input = Encoding.UTF8.GetBytes($"SMigration.Metadata_TableRegistry.ApplyOrder|{schemaName}.{tableName}".ToUpperInvariant());
        var hash = sha256.ComputeHash(input);
        var positiveValue = BitConverter.ToInt32(hash, 0) & int.MaxValue;
        return 10000 + (positiveValue % 500000);
    }

    public static async Task<List<MetadataRegistryRow>> ReadMetadataRegistryAsync(
        SqlConnection cn,
        SqlTransaction? tx,
        CancellationToken cancellationToken)
    {
        var rows = new List<MetadataRegistryRow>();

        await using var cmd = new SqlCommand(@"
SELECT
    tr.Guid,
    tr.SchemaName,
    tr.TableName,
    tr.GuidColumnName,
    tr.PrimaryKeyColumnName
FROM SMigration.Metadata_TableRegistry AS tr
WHERE tr.RowStatus NOT IN (0,254)
  AND tr.IsEnabled = 1
ORDER BY
    tr.ApplyOrder,
    tr.SchemaName,
    tr.TableName;", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            rows.Add(new MetadataRegistryRow
            {
                RegistryGuid = (Guid)reader["Guid"],
                SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                TableName = Convert.ToString(reader["TableName"]) ?? string.Empty,
                GuidColumnName = Convert.ToString(reader["GuidColumnName"]) ?? string.Empty,
                PrimaryKeyColumnName = Convert.ToString(reader["PrimaryKeyColumnName"]) ?? string.Empty
            });
        }

        return rows;
    }

    public static async Task<bool> TableExistsAsync(
        SqlConnection cn,
        SqlTransaction? tx,
        string schemaName,
        string tableName,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
SELECT CONVERT(BIT, CASE WHEN EXISTS
(
    SELECT 1
    FROM sys.schemas AS s
    INNER JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
    WHERE s.name = @SchemaName
      AND t.name = @TableName
) THEN 1 ELSE 0 END);", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = schemaName });
        cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = tableName });

        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(cancellationToken));
    }

    public static async Task<bool> ColumnExistsAsync(
        SqlConnection cn,
        SqlTransaction? tx,
        string schemaName,
        string tableName,
        string columnName,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
SELECT CONVERT(BIT, CASE WHEN EXISTS
(
    SELECT 1
    FROM sys.schemas AS s
    INNER JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
    INNER JOIN sys.columns AS c
        ON c.object_id = t.object_id
    WHERE s.name = @SchemaName
      AND t.name = @TableName
      AND c.name = @ColumnName
) THEN 1 ELSE 0 END);", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = schemaName });
        cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = tableName });
        cmd.Parameters.Add(new SqlParameter("@ColumnName", SqlDbType.NVarChar, 128) { Value = columnName });

        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(cancellationToken));
    }

    public static async Task<HashSet<string>> ReadStageColumnNamesAsync(
        SqlConnection cn,
        SqlTransaction? tx,
        string schemaName,
        string tableName,
        CancellationToken cancellationToken)
    {
        var columns = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        await using var cmd = new SqlCommand(@"
SELECT c.name
FROM sys.schemas AS s
INNER JOIN sys.tables AS t
    ON t.schema_id = s.schema_id
INNER JOIN sys.columns AS c
    ON c.object_id = t.object_id
WHERE s.name = @SchemaName
  AND t.name = @TableName
  AND c.is_computed = 0
  AND c.system_type_id <> 189
ORDER BY c.column_id;", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = schemaName });
        cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = tableName });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            columns.Add(Convert.ToString(reader["name"]) ?? string.Empty);
        }

        return columns;
    }

    public static async Task<List<MetadataPayloadRow>> ReadMetadataPayloadRowsAsync(
        SqlConnection cn,
        SqlTransaction? tx,
        MetadataRegistryRow registry,
        IEnumerable<string> columnNames,
        bool activeOnly,
        CancellationToken cancellationToken,
        bool retiredOnly = false)
    {
        var rows = new List<MetadataPayloadRow>();
        var orderedColumns = columnNames.OrderBy(column => column, StringComparer.OrdinalIgnoreCase).ToList();

        // Re-order to physical column order for stable JSON by querying has already been ordered before insertion into HashSet.
        // The payload comparison remains deterministic because both source and target use the same list here.
        var columnList = string.Join(", ", orderedColumns.Select(QuoteName));
        var objectName = $"{QuoteName(registry.SchemaName)}.{QuoteName(registry.TableName)}";
        var hasRowStatus = orderedColumns.Contains("RowStatus", StringComparer.OrdinalIgnoreCase);

        // A table without RowStatus has no retired rows; retiredOnly must not fall back to "all rows".
        var whereClause = !hasRowStatus
            ? retiredOnly ? "WHERE 1 = 0" : string.Empty
            : retiredOnly
                ? "WHERE s.[RowStatus] = 254"
                : activeOnly
                    ? "WHERE s.[RowStatus] NOT IN (0,254)"
                    : string.Empty;

        var sourceRowStatusExpression = hasRowStatus
            ? "TRY_CONVERT(TINYINT, s.[RowStatus])"
            : "NULL";

        var sql = $@"
SELECT
    CONVERT(UNIQUEIDENTIFIER, s.{QuoteName(registry.GuidColumnName)}) AS RowGuid,
    TRY_CONVERT(BIGINT, s.{QuoteName(registry.PrimaryKeyColumnName)}) AS RowId,
    {sourceRowStatusExpression} AS RowStatus,
    (
        SELECT {columnList}
        FROM {objectName} AS sj
        WHERE sj.{QuoteName(registry.GuidColumnName)} = s.{QuoteName(registry.GuidColumnName)}
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS PayloadJson
FROM {objectName} AS s
{whereClause};";

        await using var cmd = new SqlCommand(sql, cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 600
        };

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            rows.Add(new MetadataPayloadRow
            {
                RowGuid = (Guid)reader["RowGuid"],
                RowId = reader["RowId"] == DBNull.Value ? null : Convert.ToInt64(reader["RowId"]),
                RowStatus = reader["RowStatus"] == DBNull.Value ? null : Convert.ToByte(reader["RowStatus"]),
                PayloadJson = Convert.ToString(reader["PayloadJson"]) ?? "{}"
            });
        }

        return rows;
    }

    public static async Task BulkInsertStagedRowsAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid runGuid,
        IReadOnlyList<(Guid RegistryGuid, MetadataPayloadRow SourceRow, byte[] SourceHash, string? TargetPayloadJson, byte[]? TargetHash, string DifferenceType)> stagedRows,
        CancellationToken cancellationToken)
    {
        if (stagedRows.Count == 0)
        {
            return;
        }

        var table = new DataTable();
        table.Columns.Add("Guid", typeof(Guid));
        table.Columns.Add("RowStatus", typeof(byte));
        table.Columns.Add("RunGuid", typeof(Guid));
        table.Columns.Add("RegistryGuid", typeof(Guid));
        table.Columns.Add("SourceRowGuid", typeof(Guid));
        table.Columns.Add("SourceRowId", typeof(long));
        table.Columns.Add("SourceRowStatus", typeof(byte));
        table.Columns.Add("SourcePayloadJson", typeof(string));
        table.Columns.Add("SourcePayloadHash", typeof(byte[]));
        table.Columns.Add("TargetPayloadJson", typeof(string));
        table.Columns.Add("TargetPayloadHash", typeof(byte[]));
        table.Columns.Add("DifferenceType", typeof(string));
        table.Columns.Add("CreatedOnUtc", typeof(DateTime));

        var createdOnUtc = DateTime.UtcNow;

        foreach (var row in stagedRows)
        {
            var dataRow = table.NewRow();
            dataRow["Guid"] = Guid.NewGuid();
            dataRow["RowStatus"] = (byte)1;
            dataRow["RunGuid"] = runGuid;
            dataRow["RegistryGuid"] = row.RegistryGuid;
            dataRow["SourceRowGuid"] = row.SourceRow.RowGuid;
            dataRow["SourceRowId"] = row.SourceRow.RowId.HasValue ? (object)row.SourceRow.RowId.Value : DBNull.Value;
            dataRow["SourceRowStatus"] = row.SourceRow.RowStatus.HasValue ? (object)row.SourceRow.RowStatus.Value : DBNull.Value;
            dataRow["SourcePayloadJson"] = row.SourceRow.PayloadJson;
            dataRow["SourcePayloadHash"] = row.SourceHash;
            dataRow["TargetPayloadJson"] = (object?)row.TargetPayloadJson ?? DBNull.Value;
            dataRow["TargetPayloadHash"] = (object?)row.TargetHash ?? DBNull.Value;
            dataRow["DifferenceType"] = row.DifferenceType;
            dataRow["CreatedOnUtc"] = createdOnUtc;
            table.Rows.Add(dataRow);
        }

        using var bulkCopy = new SqlBulkCopy(cn, SqlBulkCopyOptions.Default, tx)
        {
            DestinationTableName = "SMigration.Metadata_StagedRows",
            BulkCopyTimeout = 1800
        };

        foreach (DataColumn column in table.Columns)
        {
            bulkCopy.ColumnMappings.Add(column.ColumnName, column.ColumnName);
        }

        await bulkCopy.WriteToServerAsync(table, cancellationToken);
    }

    public static async Task AddValidationIssueAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid runGuid,
        Guid? registryGuid,
        Guid? sourceRowGuid,
        string severity,
        string issueCode,
        string issueMessage,
        string detailsJson,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
INSERT INTO SMigration.Metadata_ValidationIssues
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    Severity,
    IssueCode,
    IssueMessage,
    DetailsJson,
    CreatedOnUtc
)
VALUES
(
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    @SourceRowGuid,
    @Severity,
    @IssueCode,
    @IssueMessage,
    @DetailsJson,
    SYSUTCDATETIME()
);", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@RegistryGuid", SqlDbType.UniqueIdentifier) { Value = registryGuid.HasValue ? (object)registryGuid.Value : DBNull.Value });
        cmd.Parameters.Add(new SqlParameter("@SourceRowGuid", SqlDbType.UniqueIdentifier) { Value = sourceRowGuid.HasValue ? (object)sourceRowGuid.Value : DBNull.Value });
        cmd.Parameters.Add(new SqlParameter("@Severity", SqlDbType.NVarChar, 20) { Value = severity });
        cmd.Parameters.Add(new SqlParameter("@IssueCode", SqlDbType.NVarChar, 100) { Value = issueCode });
        cmd.Parameters.Add(new SqlParameter("@IssueMessage", SqlDbType.NVarChar, 2000) { Value = issueMessage });
        cmd.Parameters.Add(new SqlParameter("@DetailsJson", SqlDbType.NVarChar, -1) { Value = detailsJson });

        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public static async Task AddExecutionLogAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid runGuid,
        string stepName,
        string stepStatus,
        string message,
        string detailsJson,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand("SMigration.MetadataExecutionLog_Add", cn, tx)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@StepName", SqlDbType.NVarChar, 100) { Value = stepName });
        cmd.Parameters.Add(new SqlParameter("@StepStatus", SqlDbType.NVarChar, 30) { Value = stepStatus });
        cmd.Parameters.Add(new SqlParameter("@Message", SqlDbType.NVarChar, 2000) { Value = message });
        cmd.Parameters.Add(new SqlParameter("@DetailsJson", SqlDbType.NVarChar, -1) { Value = detailsJson });

        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public static async Task ExecuteTargetNonQueryAsync(
        SqlConnection cn,
        SqlTransaction tx,
        string sql,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(sql, cn, tx)
        {
            CommandType = CommandType.Text,
            // Stopgap headroom for a full-baseline run's set-based normalisation over tens of
            // thousands of staged rows (e.g. a first DEV->UAT run) - was 300s, which is plausible
            // to hit now that the row count staged for one run can be large even though the bulk
            // insert above (not this step) was the actual cause of past timeouts.
            CommandTimeout = 1800
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public static async Task UpdateStageRunSummaryAsync(
    SqlConnection cn,
    SqlTransaction tx,
    Guid runGuid,
    CancellationToken cancellationToken)
    {
        const string sql = """
                UPDATE SMigration.Metadata_Run
                SET
                    RunStatus = N'Staged',
                    SummaryJson =
                    (
                        SELECT
                            CONCAT
                            (
                                N'{"insertCount":',
                                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Insert' THEN 1 ELSE 0 END), 0)),
                                N',"updateCount":',
                                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Update' THEN 1 ELSE 0 END), 0)),
                                N',"noChangeCount":',
                                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'NoChange' THEN 1 ELSE 0 END), 0)),
                                N',"totalCount":',
                                CONVERT(NVARCHAR(30), COUNT_BIG(1)),
                                N'}'
                            )
                        FROM SMigration.Metadata_StagedRows AS sr
                        WHERE sr.RunGuid = @RunGuid
                          AND sr.RowStatus NOT IN (0,254)
                    )
                WHERE Guid = @RunGuid
                  AND RowStatus NOT IN (0,254);
                """;

        await using var cmd = new SqlCommand(sql, cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public static byte[] ComputeSha256(string value) =>
        SHA256.HashData(Encoding.Unicode.GetBytes(value ?? string.Empty));

    public static string QuoteName(string identifier) =>
        $"[{identifier.Replace("]", "]]")}]";

    public static bool IsSafeSqlIdentifier(string identifier) =>
        !string.IsNullOrWhiteSpace(identifier) &&
        identifier.Length <= 128 &&
        identifier.All(ch => char.IsLetterOrDigit(ch) || ch == '_' || ch == '#');

    public static async Task ExecuteNonQueryAsync(SqlConnection cn, string procedureName, CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(procedureName, cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public static Dictionary<string, string> ParseJsonDictionary(string json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return new Dictionary<string, string>();
        }

        try
        {
            using var document = JsonDocument.Parse(json);
            if (document.RootElement.ValueKind != JsonValueKind.Object)
            {
                return new Dictionary<string, string>();
            }

            var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var property in document.RootElement.EnumerateObject())
            {
                result[property.Name] = property.Value.ValueKind switch
                {
                    JsonValueKind.Null => string.Empty,
                    JsonValueKind.String => property.Value.GetString() ?? string.Empty,
                    _ => property.Value.GetRawText()
                };
            }
            return result;
        }
        catch (JsonException)
        {
            return new Dictionary<string, string>();
        }
    }
}
