using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Concursus.EF.SchemaMigration;

/// <summary>
/// Pure Schema Migration rules shared by the gRPC workbench (CoreService) and the headless CLI:
/// definition normalisation and hashing, source/target diffing, validation, notes and staleness.
/// </summary>
public static class SchemaMigrationRules
{
    public const string SchemaMigrationCreated = "Created";
    public const string SchemaMigrationCompared = "Compared";
    public const string SchemaMigrationValidated = "Validated";
    public const string SchemaMigrationValidationFailed = "ValidationFailed";
    public const string SchemaMigrationReviewed = "Reviewed";
    public const string SchemaMigrationDeploymentRecorded = "DeploymentRecorded";
    public const string SchemaSnapshotContract = "R7C4";

    public static bool IsDevelopmentSchemaSource(string sourceEnvironment, string sourceDatabaseName)
    {
        if (!string.IsNullOrWhiteSpace(sourceEnvironment))
        {
            return sourceEnvironment.Trim().Equals("DEV", StringComparison.OrdinalIgnoreCase)
                || sourceEnvironment.Trim().Equals("DEVELOPMENT", StringComparison.OrdinalIgnoreCase);
        }

        var databaseName = sourceDatabaseName?.Trim() ?? string.Empty;
        return databaseName.Equals("CymBuild_Dev", StringComparison.OrdinalIgnoreCase)
            || databaseName.Equals("Concursus_Dev", StringComparison.OrdinalIgnoreCase)
            || databaseName.EndsWith("_Dev", StringComparison.OrdinalIgnoreCase)
            || databaseName.EndsWith("-Dev", StringComparison.OrdinalIgnoreCase);
    }

    public static string CompactSchemaDiagnostic(string value, int maximumLength)
    {
        var compact = (value ?? string.Empty)
            .Replace('\r', ' ')
            .Replace('\n', ' ')
            .Trim();

        return compact.Length <= maximumLength
            ? compact
            : compact[..maximumLength] + "...";
    }

    public static string BuildSchemaStableObjectKey(
        string objectType,
        string schemaName,
        string objectName,
        string parentObjectName) =>
        string.Join(
            "|",
            (objectType ?? string.Empty).Trim().ToUpperInvariant(),
            (schemaName ?? string.Empty).Trim().ToUpperInvariant(),
            (objectName ?? string.Empty).Trim().ToUpperInvariant(),
            (parentObjectName ?? string.Empty).Trim().ToUpperInvariant());

    public static List<SchemaComparisonDraft> BuildSchemaComparisonRows(
        IEnumerable<SchemaObjectSnapshot> sourceObjects,
        IEnumerable<SchemaObjectSnapshot> targetObjects,
        ISet<string>? excludedStableObjectKeys = null)
    {
        static Dictionary<string, SchemaObjectSnapshot> BuildLookup(IEnumerable<SchemaObjectSnapshot> rows) =>
            rows.GroupBy(x => x.Key, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(x => x.Key, x => x.First(), StringComparer.OrdinalIgnoreCase);

        var source = BuildLookup(sourceObjects);
        var target = BuildLookup(targetObjects);
        var structurallyEquivalentSystemNamedConstraintKeys =
            FindStructurallyEquivalentSystemNamedConstraintKeys(source, target);
        var keys = source.Keys.Concat(target.Keys).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x, StringComparer.OrdinalIgnoreCase);
        var rows = new List<SchemaComparisonDraft>();

        foreach (var key in keys)
        {
            if (structurallyEquivalentSystemNamedConstraintKeys.Contains(key))
            {
                continue;
            }

            if (excludedStableObjectKeys is not null && excludedStableObjectKeys.Contains(key.ToUpperInvariant()))
            {
                continue;
            }

            source.TryGetValue(key, out var sourceRow);
            target.TryGetValue(key, out var targetRow);
            var selected = sourceRow ?? targetRow;
            if (selected is null)
            {
                continue;
            }

            /*
                SCore.PostDeploymentScript owns record-history trigger convergence in every
                controlled target environment. DEV intentionally skips that lifecycle, so its
                checked-in/generated trigger text is not authoritative promotion input. Keep
                these objects out of the selectable plan; successful comparison restoration
                recreates them from the target's current metadata and physical columns.
            */
            if (IsLifecycleManagedRecordHistoryTrigger(selected))
            {
                continue;
            }

            var differenceType = sourceRow is null
                ? "MissingInSource"
                : targetRow is null
                    ? "MissingInTarget"
                    : sourceRow.Hash.Equals(targetRow.Hash, StringComparison.OrdinalIgnoreCase)
                      || (sourceRow.SupportsOperationalSchemaBindingLifecycle
                          && targetRow.SupportsOperationalSchemaBindingLifecycle
                          && sourceRow.OperationalHash.Equals(targetRow.OperationalHash, StringComparison.OrdinalIgnoreCase))
                        ? "Equal"
                        : "Different";

            var objectType = selected.ObjectType;
            var isDeclarativeRemoval = differenceType.Equals("MissingInSource", StringComparison.OrdinalIgnoreCase)
                && objectType is "Constraint" or "Index";
            var isDestructiveRisk = differenceType == "MissingInSource"
                || (differenceType == "Different" && objectType.Equals("Table", StringComparison.OrdinalIgnoreCase));

            rows.Add(new SchemaComparisonDraft
            {
                ComparisonGuid = Guid.NewGuid(),
                ObjectType = objectType,
                SchemaName = selected.SchemaName,
                ObjectName = selected.ObjectName,
                ParentObjectName = selected.ParentObjectName,
                DifferenceType = differenceType,
                SourceHash = sourceRow?.Hash ?? string.Empty,
                TargetHash = targetRow?.Hash ?? string.Empty,
                SourceDefinition = sourceRow?.Definition ?? string.Empty,
                TargetDefinition = targetRow?.Definition ?? string.Empty,
                IsDeployable = (differenceType is "MissingInTarget" or "Different") || isDeclarativeRemoval,
                IsDestructiveRisk = isDestructiveRisk,
                Notes = BuildSchemaComparisonNote(differenceType, objectType, isDestructiveRisk)
            });
        }

        return rows;
    }

    public static bool IsLifecycleManagedRecordHistoryTrigger(SchemaObjectSnapshot row) =>
        row.ObjectType.Equals("Trigger", StringComparison.OrdinalIgnoreCase)
        && !string.IsNullOrWhiteSpace(row.ParentObjectName)
        && row.ObjectName.StartsWith("tg_", StringComparison.OrdinalIgnoreCase)
        && row.ObjectName.EndsWith("_RecordHistory", StringComparison.OrdinalIgnoreCase);

    private static HashSet<string> FindStructurallyEquivalentSystemNamedConstraintKeys(
        IReadOnlyDictionary<string, SchemaObjectSnapshot> source,
        IReadOnlyDictionary<string, SchemaObjectSnapshot> target)
    {
        static string BuildStructuralKey(SchemaObjectSnapshot row) =>
            string.Join(
                "|",
                row.ObjectType.ToUpperInvariant(),
                row.SchemaName.ToUpperInvariant(),
                row.ParentObjectName.ToUpperInvariant(),
                row.Hash.ToUpperInvariant());

        static Dictionary<string, List<SchemaObjectSnapshot>> BuildStructuralLookup(
            IEnumerable<SchemaObjectSnapshot> rows) =>
            rows.Where(IsSystemNamedKeyConstraint)
                .GroupBy(BuildStructuralKey, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(
                    group => group.Key,
                    group => group.ToList(),
                    StringComparer.OrdinalIgnoreCase);

        var sourceByStructure = BuildStructuralLookup(source.Values);
        var targetByStructure = BuildStructuralLookup(target.Values);
        var equivalentKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var sourceGroup in sourceByStructure)
        {
            if (sourceGroup.Value.Count != 1
                || !targetByStructure.TryGetValue(sourceGroup.Key, out var targetRows)
                || targetRows.Count != 1)
            {
                continue;
            }

            equivalentKeys.Add(sourceGroup.Value[0].Key);
            equivalentKeys.Add(targetRows[0].Key);
        }

        return equivalentKeys;
    }

    private static bool IsSystemNamedKeyConstraint(SchemaObjectSnapshot row) =>
        row.ObjectType.Equals("Constraint", StringComparison.OrdinalIgnoreCase)
        && IsSystemNamedKeyConstraintDefinition(row.Definition);

    private static bool IsSystemNamedKeyConstraintDefinition(string? definition) =>
        !string.IsNullOrEmpty(definition)
        && definition.StartsWith("CYB_CONSTRAINT_V2|", StringComparison.Ordinal)
        && definition.Contains("\"IsSystemNamed\":true", StringComparison.Ordinal)
        && (definition.Contains("\"ConstraintKind\":\"PRIMARY_KEY\"", StringComparison.Ordinal)
            || definition.Contains("\"ConstraintKind\":\"UNIQUE\"", StringComparison.Ordinal));

    public static List<SchemaValidationDraft> BuildSchemaValidationIssues(
        IEnumerable<SchemaComparisonRowRecord> rows,
        bool hasComparisonRows)
    {
        var issues = new List<SchemaValidationDraft>();
        var rowList = rows.ToList();

        if (rowList.Count == 0)
        {
            issues.Add(new SchemaValidationDraft
            {
                Severity = "Fail",
                IssueCode = hasComparisonRows ? "NO_SELECTED_ROWS" : "NO_COMPARISON_ROWS",
                IssueMessage = hasComparisonRows
                    ? "No schema rows are selected. Save at least one deployable row before validation."
                    : "No schema comparison rows exist. Run Stage & Compare before validation.",
                DetailsJson = "{}"
            });
            return issues;
        }

        foreach (var row in rowList.Where(x => !x.DifferenceType.Equals("Equal", StringComparison.OrdinalIgnoreCase)))
        {
            var requiresDedicatedMigration = row.DifferenceType.Equals("Different", StringComparison.OrdinalIgnoreCase)
                && (row.ObjectType is "TableType" or "Sequence");
            var hasRunnerObjectTypeMapping = row.ObjectType is
                "Schema" or
                "Table" or
                "TableType" or
                "Sequence" or
                "Function" or
                "View" or
                "StoredProcedure" or
                "Trigger" or
                "Constraint" or
                "Index";
            var unsupportedObjectType = !hasRunnerObjectTypeMapping;
            var constraintDefinition = row.DifferenceType.Equals("MissingInSource", StringComparison.OrdinalIgnoreCase)
                ? row.TargetDefinition
                : row.SourceDefinition;
            var constraintSnapshotRequiresRefresh = row.ObjectType.Equals("Constraint", StringComparison.OrdinalIgnoreCase)
                && !constraintDefinition.StartsWith("CYB_CONSTRAINT_V2|", StringComparison.Ordinal);
            var tableSnapshotRequiresRefresh = row.ObjectType.Equals("Table", StringComparison.OrdinalIgnoreCase)
                && row.DifferenceType.Equals("Different", StringComparison.OrdinalIgnoreCase)
                && (!row.SourceDefinition.StartsWith("CYB_TABLE_V2|", StringComparison.Ordinal)
                    || !row.TargetDefinition.StartsWith("CYB_TABLE_V2|", StringComparison.Ordinal));
            var indexDefinition = row.DifferenceType.Equals("MissingInSource", StringComparison.OrdinalIgnoreCase)
                ? row.TargetDefinition
                : row.SourceDefinition;
            var indexSnapshotRequiresRefresh = row.ObjectType.Equals("Index", StringComparison.OrdinalIgnoreCase)
                && !indexDefinition.StartsWith("CYB_INDEX_V2|", StringComparison.Ordinal);
            var isConstraintRemoval = row.ObjectType.Equals("Constraint", StringComparison.OrdinalIgnoreCase)
                && row.DifferenceType.Equals("MissingInSource", StringComparison.OrdinalIgnoreCase);
            // A system-named PRIMARY KEY / UNIQUE constraint's name is generated per database, so the
            // runner can only recreate it under an explicit copy of another environment's name
            // (is_system_named = 0, which never verifies) or drop a target constraint whose source
            // equivalent merely has a different generated name. Structurally equivalent pairs are
            // already matched at compare time; anything left is refused rather than deployed.
            var isSystemNamedKeyConstraintChange = row.ObjectType.Equals("Constraint", StringComparison.OrdinalIgnoreCase)
                && (IsSystemNamedKeyConstraintDefinition(row.SourceDefinition)
                    || IsSystemNamedKeyConstraintDefinition(row.TargetDefinition));

            // Deterministic runner blockers remain failures. Constraint rows are first-class deployment
            // objects from R40, but they must come from the V2 declarative snapshot so the runner can
            // create reviewed source-controlled prepare/preflight/apply artefacts without executing
            // captured database DDL directly.
            var severity = row.DifferenceType switch
            {
                _ when constraintSnapshotRequiresRefresh || tableSnapshotRequiresRefresh || indexSnapshotRequiresRefresh => "Fail",
                _ when isSystemNamedKeyConstraintChange => "Fail",
                _ when requiresDedicatedMigration || unsupportedObjectType => "Fail",
                _ when isConstraintRemoval => "Warn",
                "MissingInSource" => "Warn",
                "Different" => "Info",
                "MissingInTarget" => "Info",
                _ => "Info"
            };

            var code = row.DifferenceType switch
            {
                _ when constraintSnapshotRequiresRefresh => "CONSTRAINT_SNAPSHOT_REQUIRES_REFRESH",
                _ when tableSnapshotRequiresRefresh => "TABLE_SNAPSHOT_REQUIRES_REFRESH",
                _ when indexSnapshotRequiresRefresh => "INDEX_SNAPSHOT_REQUIRES_REFRESH",
                _ when isSystemNamedKeyConstraintChange => "SYSTEM_NAMED_CONSTRAINT_REQUIRES_EXPLICIT_NAME",
                _ when requiresDedicatedMigration => "MANUAL_RUNNER_REQUIRES_MIGRATION_SCRIPT",
                _ when unsupportedObjectType => "MANUAL_RUNNER_UNMAPPED_OBJECT_TYPE",
                _ when isConstraintRemoval => "CONSTRAINT_REMOVAL_SELECTED",
                "MissingInSource" when row.ObjectType == "Index" => "INDEX_REMOVAL_SELECTED",
                "MissingInTarget" when row.ObjectType == "Index" => "INDEX_CREATE_SELECTED",
                "Different" when row.ObjectType == "Index" => "INDEX_REPLACE_SELECTED",
                "Different" when row.ObjectType == "Table" => "TABLE_ALIGN_SELECTED",
                "MissingInSource" => "TARGET_ONLY_OBJECT",
                "MissingInTarget" when row.ObjectType == "Constraint" => "CONSTRAINT_CREATE_SELECTED",
                "Different" when row.ObjectType == "Constraint" => "CONSTRAINT_REPLACE_SELECTED",
                "MissingInTarget" => "SOURCE_ONLY_OBJECT",
                "Different" => "OBJECT_DEFINITION_DIFFERS",
                _ => "SCHEMA_DIFFERENCE"
            };

            var message = row.DifferenceType switch
            {
                _ when constraintSnapshotRequiresRefresh => "This constraint comparison was created before the R40 declarative constraint snapshot. Run Stage & Compare again before validating or accepting the plan.",
                _ when tableSnapshotRequiresRefresh => "This existing-table comparison predates the declarative table snapshot. Run Stage & Compare again before validating or accepting the plan.",
                _ when indexSnapshotRequiresRefresh => "This index comparison predates the declarative index snapshot. Run Stage & Compare again before validating or accepting the plan.",
                _ when isSystemNamedKeyConstraintChange => $"System-named {(row.SourceDefinition.Contains("\"ConstraintKind\":\"PRIMARY_KEY\"", StringComparison.Ordinal) || row.TargetDefinition.Contains("\"ConstraintKind\":\"PRIMARY_KEY\"", StringComparison.Ordinal) ? "primary key" : "unique")} constraint '{row.ObjectName}' on {row.SchemaName}.{row.ParentObjectName}: its name is generated per database, so it cannot be deployed faithfully. Give it an explicit name in source first (or remove a duplicate at source), then run Stage & Compare again, or deselect this row.",
                _ when requiresDedicatedMigration => $"Existing {row.ObjectType} definition differs. The controlled runner will not recreate it; provide a dedicated source-controlled, non-destructive migration script.",
                _ when unsupportedObjectType => $"The controlled runner has no source-controlled SQL mapping for object type {row.ObjectType}. Narrow the saved selection or add an approved runner mapping and idempotent schema artefact.",
                _ when isConstraintRemoval => "The constraint exists only in the target and has been explicitly selected for removal. Target-only constraint removal is destructive and is never included in the default deployment plan; confirm the saved explicit selection and acceptance note before deployment.",
                "MissingInSource" when row.ObjectType == "Index" => "The target-only index has been explicitly selected for removal. Removal is excluded from the default plan and remains subject to accepted destructive-risk review.",
                "MissingInSource" => "Object exists in target but not source. Treat as target drift or destructive change risk; resolve through source-controlled SQL before promotion.",
                "MissingInTarget" when row.ObjectType == "Constraint" => "The source constraint will be materialized into reviewed source-controlled preflight/apply SQL. Foreign-key and check constraints are added WITH NOCHECK so existing rows are not validated, then enabled for future changes unless the source constraint is disabled.",
                "Different" when row.ObjectType == "Constraint" => "The target constraint will be dropped and recreated from the reviewed source declarative definition. Foreign-key and check constraints are recreated WITH NOCHECK so existing rows are not validated, then enabled for future changes unless the source constraint is disabled.",
                "MissingInTarget" when row.ObjectType == "Index" => "The source rowstore index will be materialized into reviewed source-controlled preflight/apply SQL. The controlled runner verifies the table and columns before creation.",
                "Different" when row.ObjectType == "Index" => "The target rowstore index will be replaced from the reviewed declarative source definition through source-controlled prepare, preflight and apply SQL.",
                "Different" when row.ObjectType == "Table" => "The explicitly selected existing table will be aligned through reviewed source-controlled ALTER SQL. The controlled runner supports mechanically safe column additions, typed backfill for new NOT NULL columns, convertible type/nullability changes, source default alignment and explicitly accepted target-only column removal; unsupported dependencies or conversions fail closed.",
                "MissingInTarget" when row.ObjectType is "Function" or "View" or "StoredProcedure" or "Trigger" => "Object exists in the source database but not the target. The controlled runner dry-run will resolve the canonical repository file or materialize an idempotent CREATE OR ALTER source file from this accepted source-definition snapshot when the file is missing. The generated file must be reviewed and committed through the normal source-control process before later-environment promotion.",
                "MissingInTarget" => "Object exists in the source database but not the target. A dedicated source-controlled migration is required for this object type; data-bearing or structural objects are not generated or recreated automatically.",
                "Different" when row.ObjectType is "Function" or "View" or "StoredProcedure" or "Trigger" => "Object definition differs. The controlled runner uses the canonical repository file and can materialize it from the accepted source-definition snapshot when missing. Review deployment order and commit newly generated source files before later-environment promotion.",
                "Different" => "Object definition differs. Review source-controlled SQL artefact and deployment order. The external runner dry-run remains authoritative for repository file resolution.",
                _ => "Schema difference requires review."
            };

            issues.Add(new SchemaValidationDraft
            {
                ComparisonGuid = Guid.TryParse(row.ComparisonGuid, out var comparisonGuid) ? comparisonGuid : Guid.Empty,
                Severity = severity,
                IssueCode = code,
                IssueMessage = message,
                ObjectType = row.ObjectType,
                SchemaName = row.SchemaName,
                ObjectName = row.ObjectName,
                DetailsJson = JsonSerializer.Serialize(new
                {
                    row.DifferenceType,
                    row.IsDeployable,
                    row.IsDestructiveRisk,
                    row.ParentObjectName
                })
            });
        }

        return issues;
    }

    public static string BuildSchemaComparisonNote(string differenceType, string objectType, bool isDestructiveRisk) =>
        differenceType switch
        {
            "Equal" => "No schema definition difference detected.",
            "MissingInTarget" when objectType == "Constraint" => "Source constraint is missing from the target. The controlled runner can materialize and add it without validating existing rows.",
            "MissingInTarget" when objectType == "Index" => "Source rowstore index is missing from the target. The controlled runner can materialize and create it from the declarative snapshot.",
            "MissingInTarget" => "Source-controlled deployment should create this target object idempotently.",
            "MissingInSource" when objectType == "Constraint" => "Target-only constraint. It can be removed only through an explicit saved selection and accepted destructive-risk plan.",
            "MissingInSource" => "Target-only object. Investigate drift; do not remove without approval.",
            "Different" when objectType == "Constraint" => "Constraint definition differs. The controlled runner can replace it from the source declarative snapshot using source-controlled SQL.",
            "Different" when objectType == "Index" => "Index definition differs. The controlled runner can replace it from the source declarative snapshot using source-controlled SQL.",
            "Different" when objectType == "Table" => "Table definition differs. Explicit selection permits the controlled runner to materialize a guarded column-alignment migration.",
            "Different" when isDestructiveRisk => $"{objectType} differs and may require data-preserving migration planning.",
            "Different" => "Definition differs. Review source-controlled SQL and deployment ordering.",
            _ => "Schema difference requires review."
        };

    public static bool IsNewTableComparison(string objectType, string differenceType) =>
        string.Equals(objectType, "Table", StringComparison.OrdinalIgnoreCase) &&
        string.Equals(differenceType, "MissingInTarget", StringComparison.OrdinalIgnoreCase);

    public static string QuoteSqlIdentifier(string identifier) =>
        "[" + (identifier ?? string.Empty).Replace("]", "]]", StringComparison.Ordinal) + "]";

    public static readonly TimeSpan SourceSyncStalenessThreshold = TimeSpan.FromMinutes(30);

    public static bool IsSourceSyncStale(string? sourceSyncedOnUtc, DateTime utcNow)
    {
        if (string.IsNullOrWhiteSpace(sourceSyncedOnUtc))
        {
            return true;
        }

        if (!DateTime.TryParse(
                sourceSyncedOnUtc,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                out var syncedOnUtc))
        {
            return true;
        }

        return utcNow - syncedOnUtc > SourceSyncStalenessThreshold;
    }

    public static string NormalizeSchemaDefinition(string definition)
    {
        if (string.IsNullOrWhiteSpace(definition))
        {
            return string.Empty;
        }

        var builder = new StringBuilder(definition.Length);
        var inString = false;
        var i = 0;

        while (i < definition.Length)
        {
            var ch = definition[i];

            if (!inString && ch == '-' && i + 1 < definition.Length && definition[i + 1] == '-')
            {
                i += 2;
                while (i < definition.Length && definition[i] != '\r' && definition[i] != '\n')
                {
                    i++;
                }

                continue;
            }

            if (!inString && ch == '/' && i + 1 < definition.Length && definition[i + 1] == '*')
            {
                i += 2;
                while (i + 1 < definition.Length && !(definition[i] == '*' && definition[i + 1] == '/'))
                {
                    i++;
                }

                i = Math.Min(i + 2, definition.Length);
                continue;
            }

            if (ch == '\'')
            {
                builder.Append(ch);
                if (inString && i + 1 < definition.Length && definition[i + 1] == '\'')
                {
                    builder.Append(definition[i + 1]);
                    i += 2;
                    continue;
                }

                inString = !inString;
                i++;
                continue;
            }

            if (inString)
            {
                builder.Append(ch);
                i++;
                continue;
            }

            if (char.IsWhiteSpace(ch) || ch is '[' or ']')
            {
                i++;
                continue;
            }

            builder.Append(char.ToUpperInvariant(ch));
            i++;
        }

        var normalized = builder.ToString();
        return System.Text.RegularExpressions.Regex.Replace(
            normalized,
            @"\A(?:CREATEORALTER|ALTER)(FUNCTION|VIEW|PROCEDURE|PROC|TRIGGER)",
            "CREATE$1",
            System.Text.RegularExpressions.RegexOptions.CultureInvariant);
    }

    public static string RemoveOperationalSchemaBindingClause(string definition)
    {
        if (string.IsNullOrWhiteSpace(definition))
        {
            return string.Empty;
        }

        var builder = new StringBuilder(definition.Length);
        var inString = false;
        var inBracketIdentifier = false;
        var inQuotedIdentifier = false;
        var inLineComment = false;
        var blockCommentDepth = 0;
        var index = 0;
        var schemaBindingPattern = new System.Text.RegularExpressions.Regex(
            @"\GWITH\s+SCHEMABINDING\b",
            System.Text.RegularExpressions.RegexOptions.IgnoreCase
            | System.Text.RegularExpressions.RegexOptions.CultureInvariant);

        while (index < definition.Length)
        {
            var character = definition[index];
            var nextCharacter = index + 1 < definition.Length ? definition[index + 1] : '\0';

            if (inLineComment)
            {
                builder.Append(character);
                index++;
                if (character is '\r' or '\n')
                {
                    inLineComment = false;
                }

                continue;
            }

            if (blockCommentDepth > 0)
            {
                if (character == '/' && nextCharacter == '*')
                {
                    builder.Append("/*");
                    blockCommentDepth++;
                    index += 2;
                    continue;
                }

                if (character == '*' && nextCharacter == '/')
                {
                    builder.Append("*/");
                    blockCommentDepth--;
                    index += 2;
                    continue;
                }

                builder.Append(character);
                index++;
                continue;
            }

            if (inString)
            {
                builder.Append(character);
                if (character == '\'' && nextCharacter == '\'')
                {
                    builder.Append(nextCharacter);
                    index += 2;
                    continue;
                }

                if (character == '\'')
                {
                    inString = false;
                }

                index++;
                continue;
            }

            if (inBracketIdentifier)
            {
                builder.Append(character);
                if (character == ']' && nextCharacter == ']')
                {
                    builder.Append(nextCharacter);
                    index += 2;
                    continue;
                }

                if (character == ']')
                {
                    inBracketIdentifier = false;
                }

                index++;
                continue;
            }

            if (inQuotedIdentifier)
            {
                builder.Append(character);
                if (character == '"' && nextCharacter == '"')
                {
                    builder.Append(nextCharacter);
                    index += 2;
                    continue;
                }

                if (character == '"')
                {
                    inQuotedIdentifier = false;
                }

                index++;
                continue;
            }

            if (character == '-' && nextCharacter == '-')
            {
                builder.Append("--");
                inLineComment = true;
                index += 2;
                continue;
            }

            if (character == '/' && nextCharacter == '*')
            {
                builder.Append("/*");
                blockCommentDepth = 1;
                index += 2;
                continue;
            }

            if (character == '\'')
            {
                builder.Append(character);
                inString = true;
                index++;
                continue;
            }

            if (character == '[')
            {
                builder.Append(character);
                inBracketIdentifier = true;
                index++;
                continue;
            }

            if (character == '"')
            {
                builder.Append(character);
                inQuotedIdentifier = true;
                index++;
                continue;
            }

            var previousCharacterIsIdentifier = index > 0
                && (char.IsLetterOrDigit(definition[index - 1]) || definition[index - 1] is '_' or '@' or '#' or '$');
            if (!previousCharacterIsIdentifier)
            {
                var match = schemaBindingPattern.Match(definition, index);
                if (match.Success)
                {
                    index += match.Length;
                    continue;
                }
            }

            builder.Append(character);
            index++;
        }

        return builder.ToString();
    }

    public static string ComputeSchemaHash(string value)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(value ?? string.Empty));
        return Convert.ToHexString(bytes);
    }

    public static string EscapeLikeValue(string value) =>
        value.Replace("[", "[[]", StringComparison.Ordinal)
             .Replace("%", "[%]", StringComparison.Ordinal)
             .Replace("_", "[_]", StringComparison.Ordinal);

    /// <summary>
    /// Headless (CLI) selection policy. Only <c>Different</c> and <c>MissingInTarget</c> deployable rows
    /// are candidates; target-only (<c>MissingInSource</c>) rows are never auto-selected. Each candidate is
    /// evaluated by <see cref="BuildSchemaValidationIssues"/> exactly as the workbench validation would, and
    /// rows that validation would fail are skipped with that reason instead of being selected, so the saved
    /// plan always validates. Rows must carry their persisted definitions (includeDefinitions: true).
    /// </summary>
    public static SchemaHeadlessSelectionPlan PlanHeadlessSelection(IEnumerable<SchemaComparisonRowRecord> rows)
    {
        ArgumentNullException.ThrowIfNull(rows);

        var selected = new List<SchemaComparisonRowRecord>();
        var skipped = new List<SchemaHeadlessSkippedRow>();

        foreach (var row in rows)
        {
            var isCandidateDifference = row.DifferenceType.Equals("Different", StringComparison.OrdinalIgnoreCase)
                || row.DifferenceType.Equals("MissingInTarget", StringComparison.OrdinalIgnoreCase);

            if (!isCandidateDifference)
            {
                if (row.DifferenceType.Equals("MissingInSource", StringComparison.OrdinalIgnoreCase) && row.IsDeployable)
                {
                    skipped.Add(new SchemaHeadlessSkippedRow(
                        row,
                        "TARGET_ONLY_NOT_AUTO_SELECTED",
                        "Target-only (MissingInSource) removals are destructive and are never selected automatically. Select them explicitly in the Schema Migration workbench if they are intended."));
                }

                continue;
            }

            if (!row.IsDeployable)
            {
                skipped.Add(new SchemaHeadlessSkippedRow(row, "NOT_DEPLOYABLE", "The comparison row is not deployable."));
                continue;
            }

            var failure = BuildSchemaValidationIssues([row], hasComparisonRows: true)
                .FirstOrDefault(x => x.Severity.Equals("Fail", StringComparison.OrdinalIgnoreCase));
            if (failure is not null)
            {
                skipped.Add(new SchemaHeadlessSkippedRow(row, failure.IssueCode, failure.IssueMessage));
                continue;
            }

            selected.Add(row);
        }

        return new SchemaHeadlessSelectionPlan(selected, skipped);
    }
}
