using Microsoft.Data.SqlClient;
using System.Data;
using System.Text.Json;
using static Concursus.EF.SchemaMigration.SchemaMigrationRules;

namespace Concursus.EF.SchemaMigration;

// Persistence and SQL helpers of the Schema Migration engine. Moved verbatim from
// CoreService.SchemaMigration.cs so the gRPC workbench and the headless CLI share one implementation.
public sealed partial class SchemaMigrationEngine
{    private enum SchemaMaintenanceProcedure
    {
        PreDeployment,
        PostDeployment
    }

    public static bool AreSameSqlDatabase(SqlConnection sourceConnection, SqlConnection targetConnection) =>
        sourceConnection.DataSource.Trim().Equals(targetConnection.DataSource.Trim(), StringComparison.OrdinalIgnoreCase)
        && sourceConnection.Database.Trim().Equals(targetConnection.Database.Trim(), StringComparison.OrdinalIgnoreCase);

    private static async Task ExecuteSchemaMaintenanceProcedureAsync(
        SqlConnection connection,
        SchemaMaintenanceProcedure procedure,
        Guid? runGuid,
        CancellationToken cancellationToken)
    {
        var (objectName, executionSql) = procedure switch
        {
            SchemaMaintenanceProcedure.PreDeployment =>
                ("[SCore].[PreDeploymentScript]", "EXEC [SCore].[PreDeploymentScript];"),
            SchemaMaintenanceProcedure.PostDeployment =>
                ("[SCore].[PostDeploymentScript]", "EXEC [SCore].[PostDeploymentScript] @ThrowOnIssues = 1, @RunGuid = @RunGuid;"),
            _ => throw new ArgumentOutOfRangeException(nameof(procedure), procedure, "Unsupported schema maintenance procedure.")
        };

        // The lifecycle lock stops a migration bootstrap replacing these procedures mid-run.
        await using var command = new SqlCommand($@"
IF OBJECT_ID(N'{objectName}', N'P') IS NULL
BEGIN
    THROW 60380, N'Required schema maintenance procedure {objectName} is not installed in the selected database.', 1;
END;

{SchemaLifecycleLock.WrapLifecycleSql(executionSql)}", connection)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 1800
        };

        Guid? postDeploymentRunGuid = null;
        if (procedure == SchemaMaintenanceProcedure.PostDeployment)
        {
            postDeploymentRunGuid = runGuid ?? Guid.NewGuid();
            command.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier)
            {
                Value = postDeploymentRunGuid.Value
            });
        }

        try
        {
            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (SqlException ex) when (postDeploymentRunGuid.HasValue)
        {
            var diagnostics = await ReadPostDeploymentFailureDiagnosticsAsync(
                connection,
                postDeploymentRunGuid.Value,
                ex).ConfigureAwait(false);

            throw new InvalidOperationException(
                $"Post-deployment lifecycle failed for database [{connection.Database}] " +
                $"(log RunGuid {postDeploymentRunGuid.Value:D}). {diagnostics}",
                ex);
        }
    }

    private static async Task<string> ReadPostDeploymentFailureDiagnosticsAsync(
        SqlConnection connection,
        Guid postDeploymentRunGuid,
        SqlException originalException)
    {
        try
        {
            await using var command = new SqlCommand(@"
SELECT TOP (12)
      logEntry.StepName
    , logEntry.ObjectName
    , logEntry.Message
    , logEntry.ErrorNumber
    , OccurrenceCount = COUNT_BIG(1)
    , LastLogId = MAX(logEntry.ID)
FROM SCore.PostDeploymentRunLog AS logEntry
WHERE logEntry.RunGuid = @RunGuid
  AND logEntry.Severity = N'Error'
GROUP BY
      logEntry.StepName
    , logEntry.ObjectName
    , logEntry.Message
    , logEntry.ErrorNumber
ORDER BY
    MAX(logEntry.ID) DESC;", connection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 60
            };

            command.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier)
            {
                Value = postDeploymentRunGuid
            });

            var errors = new List<string>();
            await using var reader = await command.ExecuteReaderAsync(CancellationToken.None).ConfigureAwait(false);
            while (await reader.ReadAsync(CancellationToken.None).ConfigureAwait(false))
            {
                var stepName = reader.GetString(0);
                var objectName = reader.IsDBNull(1) ? string.Empty : reader.GetString(1);
                var message = CompactSchemaDiagnostic(reader.GetString(2), 600);
                var errorNumber = reader.IsDBNull(3) ? string.Empty : $" SQL {reader.GetInt32(3)}.";
                var occurrenceCount = reader.GetInt64(4);
                var objectLabel = string.IsNullOrWhiteSpace(objectName) ? string.Empty : $" {objectName}.";
                errors.Add($"{stepName}.{objectLabel} {message}{errorNumber} Occurrences: {occurrenceCount}.");
            }

            if (errors.Count > 0)
            {
                return $"Correlated SCore.PostDeploymentRunLog errors: {string.Join(" | ", errors)}";
            }
        }
        catch (Exception diagnosticException)
        {
            return $"SQL {originalException.Number}: {CompactSchemaDiagnostic(originalException.Message, 800)} " +
                $"Correlated log lookup also failed: {CompactSchemaDiagnostic(diagnosticException.Message, 400)}";
        }

        return $"SQL {originalException.Number}: {CompactSchemaDiagnostic(originalException.Message, 800)} " +
            "No correlated Error rows were available.";
    }

    private static async Task<List<string>> RestoreSchemaComparePreparationAsync(
        SqlConnection sourceConnection,
        SqlConnection targetConnection,
        bool sourcePreDeploymentAttempted,
        bool targetPreDeploymentAttempted,
        bool sourceIsDevelopment,
        bool sourceAndTargetAreSameDatabase,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        var errors = new List<string>();

        if (targetPreDeploymentAttempted && targetConnection.State == ConnectionState.Open)
        {
            try
            {
                await ExecuteSchemaMaintenanceProcedureAsync(
                    targetConnection,
                    SchemaMaintenanceProcedure.PostDeployment,
                    runGuid,
                    cancellationToken).ConfigureAwait(false);
            }
            catch (Exception recoveryException)
            {
                errors.Add($"Target recovery failed: {recoveryException.Message}");
            }
        }

        if (sourcePreDeploymentAttempted
            && !sourceIsDevelopment
            && !sourceAndTargetAreSameDatabase
            && sourceConnection.State == ConnectionState.Open)
        {
            try
            {
                await ExecuteSchemaMaintenanceProcedureAsync(
                    sourceConnection,
                    SchemaMaintenanceProcedure.PostDeployment,
                    runGuid,
                    cancellationToken).ConfigureAwait(false);
            }
            catch (Exception recoveryException)
            {
                errors.Add($"Source recovery failed: {recoveryException.Message}");
            }
        }

        return errors;
    }

    public async Task EnsureSchemaExclusionInfrastructureAsync(
        string location,
        string configuredServerName,
        string configuredDatabaseName,
        string configuredEnvironmentName,
        CancellationToken cancellationToken)
    {
        try
        {
            await _migrationBootstrapRepository.EnsureSchemaWorkbenchAsync(
                configuredServerName,
                configuredDatabaseName,
                configuredEnvironmentName,
                cancellationToken).ConfigureAwait(false);
        }
        catch (Concursus.EF.MigrationBootstrapRepository.MigrationBootstrapException ex)
        {
            throw new SchemaMigrationException(
                SchemaMigrationErrorKind.FailedPrecondition,
                $"Automatic Schema Migration {location.ToLowerInvariant()} prerequisite installation failed. {ex.Message}");
        }
    }

    public static async Task<List<SchemaExcludedObjectRecord>> ReadSchemaExcludedObjectRecordsAsync(
        SqlConnection cn,
        bool includeInactive,
        CancellationToken cancellationToken)
    {
        var records = new List<SchemaExcludedObjectRecord>();
        await using var cmd = new SqlCommand("SMigration.SchemaExcludedObjects_List", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@IncludeInactive", SqlDbType.Bit) { Value = includeInactive });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            records.Add(new SchemaExcludedObjectRecord
            {
                ID = 0,
                Guid = reader.GetGuid(0),
                ObjectType = reader.GetString(1),
                SchemaName = reader.GetString(2),
                ObjectName = reader.GetString(3),
                ParentObjectName = reader.GetString(4),
                StableObjectKey = reader.GetString(5),
                Reason = reader.GetString(6),
                ExclusionScope = reader.GetString(7),
                OriginServerName = reader.GetString(8),
                OriginDatabaseName = reader.GetString(9),
                ExcludedByUserId = reader.GetInt32(10),
                ExcludedOnUtc = reader.GetString(11),
                UnexcludedOnUtc = reader.IsDBNull(12) ? string.Empty : reader.GetString(12),
                LastSeenRunGuid = reader.IsDBNull(13) ? Guid.Empty : reader.GetGuid(13),
                LastSeenOnUtc = reader.IsDBNull(14) ? string.Empty : reader.GetString(14),
                RowStatus = reader.GetByte(15)
            });
        }

        return records;
    }

    public static async Task<Guid> ApplySchemaExcludedObjectAsync(
        SqlConnection cn,
        SqlTransaction? transaction,
        Guid exclusionGuid,
        SchemaObjectIdentity objectIdentity,
        string reason,
        bool isExcluded,
        string originServerName,
        string originDatabaseName,
        int actorUserId,
        Guid lastSeenRunGuid,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand("SMigration.SchemaExcludedObject_Apply", cn, transaction)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };
        var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
        {
            Direction = ParameterDirection.InputOutput,
            Value = exclusionGuid == Guid.Empty ? Guid.NewGuid() : exclusionGuid
        };
        cmd.Parameters.Add(guidParameter);
        cmd.Parameters.Add(new SqlParameter("@ObjectType", SqlDbType.NVarChar, 50) { Value = objectIdentity.ObjectType });
        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = objectIdentity.SchemaName });
        cmd.Parameters.Add(new SqlParameter("@ObjectName", SqlDbType.NVarChar, 512) { Value = objectIdentity.ObjectName });
        cmd.Parameters.Add(new SqlParameter("@ParentObjectName", SqlDbType.NVarChar, 512) { Value = objectIdentity.ParentObjectName });
        cmd.Parameters.Add(new SqlParameter("@Reason", SqlDbType.NVarChar, 2000) { Value = reason ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@IsExcluded", SqlDbType.Bit) { Value = isExcluded });
        cmd.Parameters.Add(new SqlParameter("@OriginServerName", SqlDbType.NVarChar, 255) { Value = originServerName ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@OriginDatabaseName", SqlDbType.NVarChar, 255) { Value = originDatabaseName ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@ActorUserId", SqlDbType.Int) { Value = actorUserId });
        cmd.Parameters.Add(new SqlParameter("@LastSeenRunGuid", SqlDbType.UniqueIdentifier) { Value = lastSeenRunGuid });
        await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        return guidParameter.Value is Guid guid ? guid : exclusionGuid;
    }

    private static async Task<SchemaExclusionSyncResult> SynchronizeSchemaExclusionsAsync(
        SqlConnection sourceConnection,
        SqlConnection targetConnection,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        var sourceRecords = await ReadSchemaExcludedObjectRecordsAsync(
            sourceConnection,
            includeInactive: true,
            cancellationToken).ConfigureAwait(false);
        if (AreSameSqlDatabase(sourceConnection, targetConnection))
        {
            return new SchemaExclusionSyncResult(sourceRecords, sourceRecords.Count, 0);
        }

        var targetRecords = await ReadSchemaExcludedObjectRecordsAsync(
            targetConnection,
            includeInactive: true,
            cancellationToken).ConfigureAwait(false);
        var sourceKeys = sourceRecords
            .Select(x => x.StableObjectKey)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var synchronizedCount = 0;
        var removedTargetOnlyCount = 0;

        await using var tx = (SqlTransaction)await targetConnection.BeginTransactionAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            foreach (var sourceRecord in sourceRecords)
            {
                await ApplySchemaExcludedObjectAsync(
                    targetConnection,
                    tx,
                    sourceRecord.Guid,
                    new SchemaObjectIdentity(
                        sourceRecord.ObjectType,
                        sourceRecord.SchemaName,
                        sourceRecord.ObjectName,
                        sourceRecord.ParentObjectName),
                    sourceRecord.Reason,
                    sourceRecord.IsActive,
                    sourceRecord.OriginServerName,
                    sourceRecord.OriginDatabaseName,
                    sourceRecord.ExcludedByUserId,
                    runGuid,
                    cancellationToken).ConfigureAwait(false);
                synchronizedCount++;
            }

            foreach (var targetOnlyRecord in targetRecords.Where(x =>
                         x.IsActive && !sourceKeys.Contains(x.StableObjectKey)))
            {
                await ApplySchemaExcludedObjectAsync(
                    targetConnection,
                    tx,
                    targetOnlyRecord.Guid,
                    new SchemaObjectIdentity(
                        targetOnlyRecord.ObjectType,
                        targetOnlyRecord.SchemaName,
                        targetOnlyRecord.ObjectName,
                        targetOnlyRecord.ParentObjectName),
                    string.Empty,
                    false,
                    sourceConnection.DataSource,
                    sourceConnection.Database,
                    -1,
                    runGuid,
                    cancellationToken).ConfigureAwait(false);
                removedTargetOnlyCount++;
            }

            await tx.CommitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            await tx.RollbackAsync(cancellationToken).ConfigureAwait(false);
            throw;
        }

        return new SchemaExclusionSyncResult(sourceRecords, synchronizedCount, removedTargetOnlyCount);
    }

    public async Task<SqlConnection> OpenTargetSqlAsync(string targetServerName, string targetDatabaseName, CancellationToken cancellationToken)
    {
        await using var templateConnection = await OpenSqlAsync(cancellationToken).ConfigureAwait(false);
        return await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            targetServerName,
            targetDatabaseName,
            cancellationToken).ConfigureAwait(false);
    }

    public static async Task<List<SchemaObjectSnapshot>> ReadSchemaSnapshotAsync(SqlConnection cn, CancellationToken cancellationToken)
    {
        var result = new List<SchemaObjectSnapshot>();
        await ReadSnapshotQueryAsync(cn, SchemaSnapshotSql.Schemas, result, cancellationToken).ConfigureAwait(false);
        await ReadSnapshotQueryAsync(cn, SchemaSnapshotSql.Tables, result, cancellationToken).ConfigureAwait(false);
        await ReadSnapshotQueryAsync(cn, SchemaSnapshotSql.TableTypes, result, cancellationToken).ConfigureAwait(false);
        await ReadSnapshotQueryAsync(cn, SchemaSnapshotSql.Modules, result, cancellationToken).ConfigureAwait(false);
        await ReadSnapshotQueryAsync(cn, SchemaSnapshotSql.Sequences, result, cancellationToken).ConfigureAwait(false);
        await ReadSnapshotQueryAsync(cn, SchemaSnapshotSql.KeyConstraints, result, cancellationToken).ConfigureAwait(false);
        await ReadSnapshotQueryAsync(cn, SchemaSnapshotSql.ForeignKeyConstraints, result, cancellationToken).ConfigureAwait(false);
        await ReadSnapshotQueryAsync(cn, SchemaSnapshotSql.CheckConstraints, result, cancellationToken).ConfigureAwait(false);
        await ReadSnapshotQueryAsync(cn, SchemaSnapshotSql.DefaultConstraints, result, cancellationToken).ConfigureAwait(false);
        await ReadSnapshotQueryAsync(cn, SchemaSnapshotSql.Indexes, result, cancellationToken).ConfigureAwait(false);
        return result;
    }

    private static async Task ReadSnapshotQueryAsync(
        SqlConnection cn,
        string sql,
        ICollection<SchemaObjectSnapshot> result,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(sql, cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 600
        };

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            var objectType = reader.GetString(0);
            var schemaName = reader.GetString(1);
            var objectName = reader.GetString(2);
            var parentObjectName = reader.IsDBNull(3) ? string.Empty : reader.GetString(3);
            var definition = reader.IsDBNull(4) ? string.Empty : reader.GetString(4);
            var normalized = NormalizeSchemaDefinition(definition);
            var supportsOperationalSchemaBinding = objectType is "View" or "Function";
            var operationalNormalized = supportsOperationalSchemaBinding
                ? NormalizeSchemaDefinition(RemoveOperationalSchemaBindingClause(definition))
                : normalized;
            result.Add(new SchemaObjectSnapshot(
                objectType,
                schemaName,
                objectName,
                parentObjectName,
                definition,
                ComputeSchemaHash(normalized),
                ComputeSchemaHash(operationalNormalized),
                supportsOperationalSchemaBinding));
        }
    }

    private static async Task InsertSchemaComparisonRowAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid runGuid,
        SchemaComparisonDraft row,
        CancellationToken cancellationToken)
    {
        await EnsureSchemaDataObjectAsync(cn, tx, row.ComparisonGuid, "SMigration", "Schema_ObjectComparisons", cancellationToken).ConfigureAwait(false);

        await using var cmd = new SqlCommand(@"
INSERT INTO SMigration.Schema_ObjectComparisons
(
    Guid,
    RowStatus,
    RunGuid,
    ObjectType,
    SchemaName,
    ObjectName,
    ParentObjectName,
    DifferenceType,
    SourceHash,
    TargetHash,
    SourceDefinition,
    TargetDefinition,
    IsDeployable,
    IsDestructiveRisk,
    Notes,
    CreatedOnUtc
)
VALUES
(
    @Guid,
    1,
    @RunGuid,
    @ObjectType,
    @SchemaName,
    @ObjectName,
    @ParentObjectName,
    @DifferenceType,
    @SourceHash,
    @TargetHash,
    @SourceDefinition,
    @TargetDefinition,
    @IsDeployable,
    @IsDestructiveRisk,
    @Notes,
    SYSUTCDATETIME()
);", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = row.ComparisonGuid });
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@ObjectType", SqlDbType.NVarChar, 50) { Value = row.ObjectType });
        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = row.SchemaName });
        cmd.Parameters.Add(new SqlParameter("@ObjectName", SqlDbType.NVarChar, 512) { Value = row.ObjectName });
        cmd.Parameters.Add(new SqlParameter("@ParentObjectName", SqlDbType.NVarChar, 512) { Value = row.ParentObjectName });
        cmd.Parameters.Add(new SqlParameter("@DifferenceType", SqlDbType.NVarChar, 30) { Value = row.DifferenceType });
        cmd.Parameters.Add(new SqlParameter("@SourceHash", SqlDbType.NVarChar, 128) { Value = row.SourceHash });
        cmd.Parameters.Add(new SqlParameter("@TargetHash", SqlDbType.NVarChar, 128) { Value = row.TargetHash });
        cmd.Parameters.Add(new SqlParameter("@SourceDefinition", SqlDbType.NVarChar, -1) { Value = row.SourceDefinition });
        cmd.Parameters.Add(new SqlParameter("@TargetDefinition", SqlDbType.NVarChar, -1) { Value = row.TargetDefinition });
        cmd.Parameters.Add(new SqlParameter("@IsDeployable", SqlDbType.Bit) { Value = row.IsDeployable });
        cmd.Parameters.Add(new SqlParameter("@IsDestructiveRisk", SqlDbType.Bit) { Value = row.IsDestructiveRisk });
        cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 2000) { Value = row.Notes });
        await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    private static async Task InsertSchemaValidationIssueAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid runGuid,
        SchemaValidationDraft issue,
        CancellationToken cancellationToken)
    {
        var issueGuid = Guid.NewGuid();
        await EnsureSchemaDataObjectAsync(cn, tx, issueGuid, "SMigration", "Schema_ValidationIssues", cancellationToken).ConfigureAwait(false);

        await using var cmd = new SqlCommand(@"
INSERT INTO SMigration.Schema_ValidationIssues
(
    Guid,
    RowStatus,
    RunGuid,
    ComparisonGuid,
    Severity,
    IssueCode,
    IssueMessage,
    ObjectType,
    SchemaName,
    ObjectName,
    DetailsJson,
    CreatedOnUtc
)
VALUES
(
    @Guid,
    1,
    @RunGuid,
    @ComparisonGuid,
    @Severity,
    @IssueCode,
    @IssueMessage,
    @ObjectType,
    @SchemaName,
    @ObjectName,
    @DetailsJson,
    SYSUTCDATETIME()
);", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = issueGuid });
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@ComparisonGuid", SqlDbType.UniqueIdentifier) { Value = issue.ComparisonGuid == Guid.Empty ? (object)DBNull.Value : issue.ComparisonGuid });
        cmd.Parameters.Add(new SqlParameter("@Severity", SqlDbType.NVarChar, 10) { Value = issue.Severity });
        cmd.Parameters.Add(new SqlParameter("@IssueCode", SqlDbType.NVarChar, 100) { Value = issue.IssueCode });
        cmd.Parameters.Add(new SqlParameter("@IssueMessage", SqlDbType.NVarChar, 2000) { Value = issue.IssueMessage });
        cmd.Parameters.Add(new SqlParameter("@ObjectType", SqlDbType.NVarChar, 50) { Value = issue.ObjectType });
        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = issue.SchemaName });
        cmd.Parameters.Add(new SqlParameter("@ObjectName", SqlDbType.NVarChar, 512) { Value = issue.ObjectName });
        cmd.Parameters.Add(new SqlParameter("@DetailsJson", SqlDbType.NVarChar, -1) { Value = issue.DetailsJson });
        await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    public static async Task DeactivateSchemaRowsAsync(
        SqlConnection cn,
        SqlTransaction tx,
        string tableName,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        if (tableName is not ("SMigration.Schema_ObjectComparisons" or "SMigration.Schema_ValidationIssues" or "SMigration.Schema_RunSelections"))
        {
            throw new InvalidOperationException("Unsupported schema migration table.");
        }

        await using var cmd = new SqlCommand($@"
UPDATE {tableName}
SET RowStatus = 254
WHERE RunGuid = @RunGuid
  AND RowStatus <> 0
  AND RowStatus <> 254;", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    public static async Task InvalidateSchemaValidationAndReviewAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        await DeactivateSchemaRowsAsync(
            cn,
            tx,
            "SMigration.Schema_ValidationIssues",
            runGuid,
            cancellationToken).ConfigureAwait(false);

        await using var cmd = new SqlCommand(@"
UPDATE SMigration.Schema_Run
SET
    RunStatus = @RunStatus,
    ValidatedOnUtc = NULL,
    ReviewedOnUtc = NULL,
    ReviewedByUserId = -1,
    IsReviewed = 0
WHERE Guid = @RunGuid
  AND RowStatus <> 0
  AND RowStatus <> 254;", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@RunStatus", SqlDbType.NVarChar, 30) { Value = SchemaMigrationCompared });
        await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    public static async Task UpdateSchemaRunStatusAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid runGuid,
        string status,
        bool compared,
        bool validated,
        bool reviewed,
        bool applied,
        string? summaryJson,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
UPDATE SMigration.Schema_Run
SET
    RunStatus = @RunStatus,
    ComparedOnUtc = CASE WHEN @Compared = 1 THEN SYSUTCDATETIME() ELSE ComparedOnUtc END,
    ValidatedOnUtc = CASE WHEN @Validated = 1 THEN SYSUTCDATETIME() WHEN @Compared = 1 THEN NULL ELSE ValidatedOnUtc END,
    ReviewedOnUtc = CASE WHEN @Reviewed = 1 THEN SYSUTCDATETIME() WHEN @Validated = 1 OR @Compared = 1 THEN NULL ELSE ReviewedOnUtc END,
    AppliedOnUtc = CASE WHEN @Applied = 1 THEN SYSUTCDATETIME() ELSE AppliedOnUtc END,
    ReviewedByUserId = CASE WHEN @Validated = 1 OR @Compared = 1 THEN -1 ELSE ReviewedByUserId END,
    IsReviewed = CASE WHEN @Reviewed = 1 THEN 1 WHEN @Validated = 1 OR @Compared = 1 THEN 0 ELSE IsReviewed END,
    SummaryJson = COALESCE(@SummaryJson, SummaryJson)
WHERE Guid = @RunGuid
  AND RowStatus <> 0
  AND RowStatus <> 254;", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@RunStatus", SqlDbType.NVarChar, 30) { Value = status });
        cmd.Parameters.Add(new SqlParameter("@Compared", SqlDbType.Bit) { Value = compared });
        cmd.Parameters.Add(new SqlParameter("@Validated", SqlDbType.Bit) { Value = validated });
        cmd.Parameters.Add(new SqlParameter("@Reviewed", SqlDbType.Bit) { Value = reviewed });
        cmd.Parameters.Add(new SqlParameter("@Applied", SqlDbType.Bit) { Value = applied });
        cmd.Parameters.Add(new SqlParameter("@SummaryJson", SqlDbType.NVarChar, -1) { Value = (object?)summaryJson ?? DBNull.Value });
        await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    public static async Task EnsureSchemaDataObjectAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid guid,
        string schemeName,
        string objectName,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand("SMigration.SchemaDataObject_Ensure", cn, tx)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = guid });
        cmd.Parameters.Add(new SqlParameter("@SchemeName", SqlDbType.NVarChar, 255) { Value = schemeName });
        cmd.Parameters.Add(new SqlParameter("@ObjectName", SqlDbType.NVarChar, 255) { Value = objectName });
        await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    public static async Task AddSchemaExecutionLogAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid runGuid,
        string stepName,
        string stepStatus,
        string message,
        string detailsJson,
        CancellationToken cancellationToken)
    {
        var logGuid = Guid.NewGuid();
        await EnsureSchemaDataObjectAsync(cn, tx, logGuid, "SMigration", "Schema_ExecutionLog", cancellationToken).ConfigureAwait(false);

        await using var cmd = new SqlCommand(@"
INSERT INTO SMigration.Schema_ExecutionLog
(
    Guid,
    RowStatus,
    RunGuid,
    StepName,
    StepStatus,
    Message,
    DetailsJson,
    CreatedOnUtc
)
VALUES
(
    @Guid,
    1,
    @RunGuid,
    @StepName,
    @StepStatus,
    @Message,
    @DetailsJson,
    SYSUTCDATETIME()
);", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = logGuid });
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@StepName", SqlDbType.NVarChar, 100) { Value = stepName });
        cmd.Parameters.Add(new SqlParameter("@StepStatus", SqlDbType.NVarChar, 30) { Value = stepStatus });
        cmd.Parameters.Add(new SqlParameter("@Message", SqlDbType.NVarChar, 2000) { Value = message });
        cmd.Parameters.Add(new SqlParameter("@DetailsJson", SqlDbType.NVarChar, -1) { Value = detailsJson });
        await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    public static async Task<SchemaRunRecord> ReadSchemaRunSummaryAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
SELECT TOP (1)
    r.Guid,
    r.SourceEnvironment,
    r.TargetEnvironment,
    r.SourceServerName,
    r.SourceDatabaseName,
    r.TargetServerName,
    r.TargetDatabaseName,
    r.JiraReference,
    r.ReleaseReference,
    r.RunStatus,
    r.IsReviewed,
    r.CreatedOnUtc,
    r.ComparedOnUtc,
    r.ValidatedOnUtc,
    r.ReviewedOnUtc,
    r.AppliedOnUtc,
    r.Notes,
    r.SummaryJson,
    r.SourceSyncedOnUtc,
    r.SourceSyncCommit
FROM SMigration.Schema_Run AS r
WHERE r.Guid = @RunGuid
  AND r.RowStatus <> 0
  AND r.RowStatus <> 254
ORDER BY r.ID DESC;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        if (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            return MapSchemaRunRecord(reader);
        }

        throw new SchemaMigrationException(SchemaMigrationErrorKind.NotFound, "Schema migration run was not found.");
    }

    public static async Task<SchemaValidationResult> ReadSchemaValidationAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        var response = new SchemaValidationResult();
        await using var cmd = new SqlCommand(@"
SELECT
    i.Guid,
    i.ComparisonGuid,
    i.Severity,
    i.IssueCode,
    i.IssueMessage,
    i.ObjectType,
    i.SchemaName,
    i.ObjectName,
    i.DetailsJson
FROM SMigration.Schema_ValidationIssues AS i
WHERE i.RunGuid = @RunGuid
  AND i.RowStatus <> 0
  AND i.RowStatus <> 254
ORDER BY
    CASE i.Severity WHEN N'Fail' THEN 1 WHEN N'Warn' THEN 2 ELSE 3 END,
    i.ObjectType,
    i.SchemaName,
    i.ObjectName;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            var item = new SchemaValidationIssueRecord
            {
                IssueGuid = reader.GetGuid(0).ToString(),
                ComparisonGuid = reader.IsDBNull(1) ? string.Empty : reader.GetGuid(1).ToString(),
                Severity = reader.GetString(2),
                IssueCode = reader.GetString(3),
                IssueMessage = reader.GetString(4),
                ObjectType = reader.GetString(5),
                SchemaName = reader.GetString(6),
                ObjectName = reader.GetString(7),
                DetailsJson = reader.GetString(8)
            };
            response.ValidationIssues.Add(item);
            if (item.Severity == "Fail") response.FailCount++;
            if (item.Severity == "Warn") response.WarnCount++;
            if (item.Severity == "Info") response.InfoCount++;
        }

        return response;
    }

    public static async Task<List<SchemaComparisonRowRecord>> ReadSchemaComparisonRowsAsync(
        SqlConnection cn,
        Guid runGuid,
        string objectType,
        string differenceType,
        string searchText,
        bool includeDefinitions,
        Guid? comparisonGuid,
        CancellationToken cancellationToken)
    {
        var rows = new List<SchemaComparisonRowRecord>();
        await using var cmd = new SqlCommand(@"
SELECT TOP (5000)
    c.Guid,
    c.ObjectType,
    c.SchemaName,
    c.ObjectName,
    c.ParentObjectName,
    c.DifferenceType,
    c.IsDeployable,
    c.IsDestructiveRisk,
    c.SourceHash,
    c.TargetHash,
    CASE WHEN @IncludeDefinitions = 1 THEN c.SourceDefinition ELSE N'' END AS SourceDefinition,
    CASE WHEN @IncludeDefinitions = 1 THEN c.TargetDefinition ELSE N'' END AS TargetDefinition,
    c.Notes,
    CONVERT(BIT, CASE
        WHEN c.IsDeployable = 1 AND ISNULL(sel.IsSelected, CONVERT(BIT, 0)) = 1 THEN 1
        ELSE 0
    END) AS IsSelected,
    CASE WHEN sel.Guid IS NULL THEN CONVERT(BIT, 0) ELSE CONVERT(BIT, 1) END AS HasExplicitSelection,
    ISNULL(sel.CopyReferenceData, CONVERT(BIT, 0)) AS CopyReferenceData
FROM SMigration.Schema_ObjectComparisons AS c
OUTER APPLY
(
    SELECT TOP (1)
        rs.Guid,
        rs.IsSelected,
        rs.CopyReferenceData
    FROM SMigration.Schema_RunSelections AS rs
    WHERE rs.RunGuid = c.RunGuid
      AND rs.ObjectType = c.ObjectType
      AND rs.SchemaName = c.SchemaName
      AND rs.ObjectName = c.ObjectName
      AND rs.ParentObjectName = c.ParentObjectName
      AND rs.RowStatus <> 0
      AND rs.RowStatus <> 254
    ORDER BY rs.ID DESC
) AS sel
WHERE c.RunGuid = @RunGuid
  AND c.RowStatus <> 0
  AND c.RowStatus <> 254
  AND NOT EXISTS
  (
      SELECT 1
      FROM SMigration.Schema_ExcludedObjects AS excluded
      WHERE excluded.ObjectType = c.ObjectType
        AND excluded.SchemaName = c.SchemaName
        AND excluded.ObjectName = c.ObjectName
        AND excluded.ParentObjectName = c.ParentObjectName
        AND excluded.RowStatus <> 0
        AND excluded.RowStatus <> 254
  )
  AND (@ComparisonGuid IS NULL OR c.Guid = @ComparisonGuid)
  AND (@ObjectType = N'' OR c.ObjectType = @ObjectType)
  AND (@DifferenceType = N'' OR c.DifferenceType = @DifferenceType)
  AND
  (
      @SearchText = N''
      OR c.SchemaName LIKE @SearchPattern
      OR c.ObjectName LIKE @SearchPattern
      OR c.ParentObjectName LIKE @SearchPattern
  )
ORDER BY
    CASE c.DifferenceType WHEN N'Different' THEN 1 WHEN N'MissingInTarget' THEN 2 WHEN N'MissingInSource' THEN 3 ELSE 4 END,
    c.ObjectType,
    c.SchemaName,
    c.ObjectName;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@ObjectType", SqlDbType.NVarChar, 50) { Value = objectType ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@DifferenceType", SqlDbType.NVarChar, 30) { Value = differenceType ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@SearchText", SqlDbType.NVarChar, 200) { Value = searchText ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@SearchPattern", SqlDbType.NVarChar, 260) { Value = $"%{EscapeLikeValue(searchText ?? string.Empty)}%" });
        cmd.Parameters.Add(new SqlParameter("@IncludeDefinitions", SqlDbType.Bit) { Value = includeDefinitions });
        cmd.Parameters.Add(new SqlParameter("@ComparisonGuid", SqlDbType.UniqueIdentifier) { Value = (object?)comparisonGuid ?? DBNull.Value });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            rows.Add(new SchemaComparisonRowRecord
            {
                ComparisonGuid = reader.GetGuid(0).ToString(),
                ObjectType = reader.GetString(1),
                SchemaName = reader.GetString(2),
                ObjectName = reader.GetString(3),
                ParentObjectName = reader.GetString(4),
                DifferenceType = reader.GetString(5),
                IsDeployable = reader.GetBoolean(6),
                IsDestructiveRisk = reader.GetBoolean(7),
                SourceHash = reader.GetString(8),
                TargetHash = reader.GetString(9),
                SourceDefinition = reader.GetString(10),
                TargetDefinition = reader.GetString(11),
                Notes = reader.GetString(12),
                IsSelected = reader.GetBoolean(13),
                HasExplicitSelection = reader.GetBoolean(14),
                CopyReferenceData = reader.GetBoolean(15)
            });
        }

        return rows;
    }

    private static async Task InsertSchemaSelectionRowAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid runGuid,
        SchemaSelectionDraft selection,
        CancellationToken cancellationToken)
    {
        var selectionGuid = Guid.NewGuid();
        await EnsureSchemaDataObjectAsync(cn, tx, selectionGuid, "SMigration", "Schema_RunSelections", cancellationToken).ConfigureAwait(false);

        await using var cmd = new SqlCommand(@"
INSERT INTO SMigration.Schema_RunSelections
(
    Guid,
    RowStatus,
    RunGuid,
    ComparisonGuid,
    ObjectType,
    SchemaName,
    ObjectName,
    ParentObjectName,
    IsSelected,
    SelectionNote,
    SelectedByUserId,
    SelectedOnUtc,
    CopyReferenceData,
    NewTableCaptureJson
)
VALUES
(
    @Guid,
    1,
    @RunGuid,
    @ComparisonGuid,
    @ObjectType,
    @SchemaName,
    @ObjectName,
    @ParentObjectName,
    @IsSelected,
    @SelectionNote,
    ISNULL(SCore.GetCurrentUserId(), -1),
    SYSUTCDATETIME(),
    @CopyReferenceData,
    @NewTableCaptureJson
);", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = selectionGuid });
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@ComparisonGuid", SqlDbType.UniqueIdentifier) { Value = selection.ComparisonGuid == Guid.Empty ? (object)DBNull.Value : selection.ComparisonGuid });
        cmd.Parameters.Add(new SqlParameter("@ObjectType", SqlDbType.NVarChar, 50) { Value = selection.ObjectType });
        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = selection.SchemaName });
        cmd.Parameters.Add(new SqlParameter("@ObjectName", SqlDbType.NVarChar, 512) { Value = selection.ObjectName });
        cmd.Parameters.Add(new SqlParameter("@ParentObjectName", SqlDbType.NVarChar, 512) { Value = selection.ParentObjectName });
        cmd.Parameters.Add(new SqlParameter("@IsSelected", SqlDbType.Bit) { Value = selection.IsSelected });
        cmd.Parameters.Add(new SqlParameter("@SelectionNote", SqlDbType.NVarChar, 2000) { Value = selection.SelectionNote });
        cmd.Parameters.Add(new SqlParameter("@CopyReferenceData", SqlDbType.Bit) { Value = selection.CopyReferenceData });
        cmd.Parameters.Add(new SqlParameter("@NewTableCaptureJson", SqlDbType.NVarChar, -1) { Value = (object?)selection.NewTableCaptureJson ?? DBNull.Value });
        await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    // CYB-566: reference (lookup) tables stay small; anything larger is almost certainly not
    // reference data and must not be copied between environments by a tick box.
    internal const int SchemaReferenceDataMaxRows = 5000;

    // Column types the runner can round-trip through JSON into a typed INSERT. Anything else
    // (binary, xml, spatial, sql_variant, hierarchyid, ...) is refused rather than approximated.
    internal static readonly HashSet<string> SchemaReferenceDataSupportedTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "bigint", "int", "smallint", "tinyint", "bit",
        "decimal", "numeric", "money", "smallmoney", "float", "real",
        "char", "varchar", "nchar", "nvarchar",
        "date", "time", "datetime", "datetime2", "smalldatetime", "datetimeoffset",
        "uniqueidentifier"
    };

    private static async Task<string> ReadSchemaNewTableCaptureJsonAsync(
        SqlConnection sourceConnection,
        string schemaName,
        string tableName,
        bool includeRows,
        CancellationToken cancellationToken)
    {
        var columnOrder = new List<string>();
        var dataColumns = new List<string>();
        var unsupported = new List<string>();

        await using (var columnCmd = new SqlCommand(@"
SELECT
    c.name AS ColumnName,
    TYPE_NAME(c.system_type_id) AS TypeName,
    c.is_computed AS IsComputed
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName), N'U')
ORDER BY c.column_id;", sourceConnection)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        })
        {
            columnCmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = schemaName });
            columnCmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = tableName });

            await using var reader = await columnCmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                var columnName = reader.GetString(0);
                var typeName = reader.GetString(1);
                var isComputed = reader.GetBoolean(2);
                columnOrder.Add(columnName);

                // rowversion/timestamp and computed columns are generated by the target itself.
                if (isComputed || typeName.Equals("timestamp", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                if (!SchemaReferenceDataSupportedTypes.Contains(typeName))
                {
                    unsupported.Add($"{columnName} ({typeName})");
                    continue;
                }

                dataColumns.Add(columnName);
            }
        }

        if (columnOrder.Count == 0)
        {
            throw new SchemaMigrationException(
                SchemaMigrationErrorKind.FailedPrecondition,
                $"Cannot prepare new table {schemaName}.{tableName}: the table was not found in the source database.");
        }

        string rowsJson = "null";
        if (includeRows)
        {
            if (unsupported.Count > 0)
            {
                throw new SchemaMigrationException(
                    SchemaMigrationErrorKind.FailedPrecondition,
                    $"Cannot copy reference data for {schemaName}.{tableName}: unsupported column type(s) {string.Join(", ", unsupported)}. Untick \"Copy reference data\" and add the rows through a reviewed script.");
            }

            var objectName = $"{QuoteSqlIdentifier(schemaName)}.{QuoteSqlIdentifier(tableName)}";
            var columnList = string.Join(", ", dataColumns.Select(QuoteSqlIdentifier));

            await using var dataCmd = new SqlCommand($@"
SELECT
    (SELECT COUNT_BIG(1) FROM {objectName}) AS RowCountValue,
    (
        SELECT {columnList}
        FROM {objectName}
        ORDER BY {QuoteSqlIdentifier(dataColumns[0])}
        FOR JSON PATH, INCLUDE_NULL_VALUES
    ) AS RowsJson;", sourceConnection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 300
            };

            await using var dataReader = await dataCmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
            await dataReader.ReadAsync(cancellationToken).ConfigureAwait(false);
            var rowCount = dataReader.GetInt64(0);
            if (rowCount > SchemaReferenceDataMaxRows)
            {
                throw new SchemaMigrationException(
                    SchemaMigrationErrorKind.FailedPrecondition,
                    $"Cannot copy reference data for {schemaName}.{tableName}: it has {rowCount:N0} rows (limit {SchemaReferenceDataMaxRows:N0}). Reference data must be a small lookup table.");
            }

            rowsJson = dataReader.IsDBNull(1) ? "[]" : dataReader.GetString(1);
        }

        // { "ColumnOrder": [source column_id order], "Rows": [...] | null }. Rows is null unless
        // "Copy reference data" was ticked; the runner always adds the -1 row itself.
        return "{\"ColumnOrder\":" + JsonSerializer.Serialize(columnOrder) + ",\"Rows\":" + rowsJson + "}";
    }

    public static async Task<SchemaSelectionCounts> ReadSchemaSelectionCountsAsync(
        SqlConnection cn,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
DECLARE @ExplicitSelectionCount INT =
(
    SELECT COUNT(1)
    FROM SMigration.Schema_RunSelections AS rs
    WHERE rs.RunGuid = @RunGuid
      AND rs.RowStatus <> 0
      AND rs.RowStatus <> 254
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Schema_ExcludedObjects AS excluded
          WHERE excluded.ObjectType = rs.ObjectType
            AND excluded.SchemaName = rs.SchemaName
            AND excluded.ObjectName = rs.ObjectName
            AND excluded.ParentObjectName = rs.ParentObjectName
            AND excluded.RowStatus <> 0
            AND excluded.RowStatus <> 254
      )
);

DECLARE @DeployableCount INT =
(
    SELECT COUNT(1)
    FROM SMigration.Schema_ObjectComparisons AS c
    WHERE c.RunGuid = @RunGuid
      AND c.RowStatus <> 0
      AND c.RowStatus <> 254
      AND c.IsDeployable = 1
      AND c.DifferenceType <> N'Equal'
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Schema_ExcludedObjects AS excluded
          WHERE excluded.ObjectType = c.ObjectType
            AND excluded.SchemaName = c.SchemaName
            AND excluded.ObjectName = c.ObjectName
            AND excluded.ParentObjectName = c.ParentObjectName
            AND excluded.RowStatus <> 0
            AND excluded.RowStatus <> 254
      )
);

SELECT
    @DeployableCount AS DeployableCount,
    (
            SELECT COUNT(1)
            FROM SMigration.Schema_ObjectComparisons AS c
            OUTER APPLY
            (
                SELECT TOP (1)
                    rs.IsSelected
                FROM SMigration.Schema_RunSelections AS rs
                WHERE rs.RunGuid = c.RunGuid
                  AND rs.ObjectType = c.ObjectType
                  AND rs.SchemaName = c.SchemaName
                  AND rs.ObjectName = c.ObjectName
                  AND rs.ParentObjectName = c.ParentObjectName
                  AND rs.RowStatus <> 0
                  AND rs.RowStatus <> 254
                ORDER BY rs.ID DESC
            ) AS sel
            WHERE c.RunGuid = @RunGuid
              AND c.RowStatus <> 0
              AND c.RowStatus <> 254
              AND c.IsDeployable = 1
              AND c.DifferenceType <> N'Equal'
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM SMigration.Schema_ExcludedObjects AS excluded
                  WHERE excluded.ObjectType = c.ObjectType
                    AND excluded.SchemaName = c.SchemaName
                    AND excluded.ObjectName = c.ObjectName
                    AND excluded.ParentObjectName = c.ParentObjectName
                    AND excluded.RowStatus <> 0
                    AND excluded.RowStatus <> 254
              )
              AND ISNULL(sel.IsSelected, CONVERT(BIT, 0)) = 1
    ) AS SelectedCount,
    @ExplicitSelectionCount AS ExplicitSelectionCount;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        if (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            return new SchemaSelectionCounts(
                Convert.ToInt32(reader.GetInt32(0)),
                Convert.ToInt32(reader.GetInt32(1)),
                Convert.ToInt32(reader.GetInt32(2)));
        }

        return new SchemaSelectionCounts(0, 0, 0);
    }

    private static string BuildSchemaSelectionKey(SchemaSelectionRequestItem item) =>
        string.Join("|", item.ObjectType, item.SchemaName, item.ObjectName, item.ParentObjectName);

    private static string BuildSchemaSelectionKey(SchemaComparisonRowRecord row) =>
        string.Join("|", row.ObjectType, row.SchemaName, row.ObjectName, row.ParentObjectName);

    public static SchemaRunRecord MapSchemaRunRecord(SqlDataReader reader)
    {
        return new SchemaRunRecord
        {
            RunGuid = reader.GetGuid(0).ToString(),
            SourceEnvironment = reader.GetString(1),
            TargetEnvironment = reader.GetString(2),
            SourceServerName = reader.GetString(3),
            SourceDatabaseName = reader.GetString(4),
            TargetServerName = reader.GetString(5),
            TargetDatabaseName = reader.GetString(6),
            JiraReference = reader.GetString(7),
            ReleaseReference = reader.GetString(8),
            RunStatus = reader.GetString(9),
            IsReviewed = reader.GetBoolean(10),
            CreatedOnUtc = FormatDateTime(reader, 11),
            ComparedOnUtc = FormatDateTime(reader, 12),
            ValidatedOnUtc = FormatDateTime(reader, 13),
            ReviewedOnUtc = FormatDateTime(reader, 14),
            AppliedOnUtc = FormatDateTime(reader, 15),
            Notes = reader.GetString(16),
            SummaryJson = reader.GetString(17),
            SourceSyncedOnUtc = FormatDateTime(reader, 18),
            SourceSyncCommit = reader.IsDBNull(19) ? string.Empty : reader.GetString(19)
        };
    }

    public static string FormatDateTime(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? string.Empty : reader.GetDateTime(ordinal).ToString("yyyy-MM-dd HH:mm:ss");
}
