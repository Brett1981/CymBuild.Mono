using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Text.Json;
using static Concursus.EF.SchemaMigration.SchemaMigrationRules;

namespace Concursus.EF.SchemaMigration;

/// <summary>
/// The Schema Migration workbench engine: create run, compare, save selection, validate and accept.
/// CoreService (gRPC) and the headless CLI both call this one implementation, so a headless run is
/// indistinguishable from one prepared in the UI. All run state lives in the TARGET database; every
/// connection is the configured template connection with its server and database swapped.
/// </summary>
public sealed partial class SchemaMigrationEngine
{
    private readonly string _templateConnectionString;
    private readonly MigrationBootstrapRepository _migrationBootstrapRepository;

    public SchemaMigrationEngine(string templateConnectionString, MigrationBootstrapRepository migrationBootstrapRepository)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(templateConnectionString);
        _templateConnectionString = templateConnectionString;
        _migrationBootstrapRepository = migrationBootstrapRepository ?? throw new ArgumentNullException(nameof(migrationBootstrapRepository));
    }

    /// <summary>
    /// Builds the engine from configuration, resolving the template connection string in the same
    /// order as CoreService (ShoreDB, CymBuild, DefaultConnection, ConnectionString).
    /// </summary>
    public SchemaMigrationEngine(IConfiguration configuration)
        : this(ResolveTemplateConnectionString(configuration), new MigrationBootstrapRepository(configuration))
    {
    }

    public static string ResolveTemplateConnectionString(IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        var cs =
            configuration.GetConnectionString("ShoreDB")
            ?? configuration.GetConnectionString("CymBuild")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? configuration.GetConnectionString("ConnectionString");

        if (string.IsNullOrWhiteSpace(cs))
            throw new InvalidOperationException("No SQL connection string found. Expected one of: Concursus, CymBuild, DefaultConnection, ConnectionString.");

        return cs;
    }

    public async Task<SchemaRunRecord> CreateRunAsync(SchemaRunCreateOptions request, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var targetBootstrap = await _migrationBootstrapRepository.EnsureSchemaWorkbenchAsync(
            request.TargetServerName,
            request.TargetDatabaseName,
            request.TargetEnvironment,
            cancellationToken).ConfigureAwait(false);

        var sourceBootstrap = await _migrationBootstrapRepository.EnsureSchemaWorkbenchAsync(
            request.SourceServerName,
            request.SourceDatabaseName,
            request.SourceEnvironment,
            cancellationToken).ConfigureAwait(false);

        await using var templateConnection = await OpenSqlAsync(cancellationToken).ConfigureAwait(false);
        await using var cn = await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            request.TargetServerName,
            request.TargetDatabaseName,
            cancellationToken).ConfigureAwait(false);

        var runGuid = Guid.NewGuid();
        await using var tx = (SqlTransaction)await cn.BeginTransactionAsync(cancellationToken).ConfigureAwait(false);

        try
        {
            await EnsureSchemaDataObjectAsync(cn, tx, runGuid, "SMigration", "Schema_Run", cancellationToken).ConfigureAwait(false);

            await using (var cmd = new SqlCommand(@"
INSERT INTO SMigration.Schema_Run
(
    Guid,
    RowStatus,
    SourceEnvironment,
    TargetEnvironment,
    SourceServerName,
    SourceDatabaseName,
    TargetServerName,
    TargetDatabaseName,
    JiraReference,
    ReleaseReference,
    RunStatus,
    IsReviewed,
    CreatedOnUtc,
    CreatedByUserId,
    Notes,
    SummaryJson
)
VALUES
(
    @Guid,
    1,
    @SourceEnvironment,
    @TargetEnvironment,
    @SourceServerName,
    @SourceDatabaseName,
    @TargetServerName,
    @TargetDatabaseName,
    @JiraReference,
    @ReleaseReference,
    @RunStatus,
    0,
    SYSUTCDATETIME(),
    ISNULL(SCore.GetCurrentUserId(), -1),
    @Notes,
    N'{}'
);", cn, tx)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 300
            })
            {
                cmd.Parameters.Add(new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = runGuid });
                cmd.Parameters.Add(new SqlParameter("@SourceEnvironment", SqlDbType.NVarChar, 20) { Value = request.SourceEnvironment ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@TargetEnvironment", SqlDbType.NVarChar, 20) { Value = request.TargetEnvironment ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@SourceServerName", SqlDbType.NVarChar, 255) { Value = request.SourceServerName ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@SourceDatabaseName", SqlDbType.NVarChar, 255) { Value = request.SourceDatabaseName ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@TargetServerName", SqlDbType.NVarChar, 255) { Value = request.TargetServerName ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@TargetDatabaseName", SqlDbType.NVarChar, 255) { Value = request.TargetDatabaseName ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@JiraReference", SqlDbType.NVarChar, 50) { Value = request.JiraReference ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@ReleaseReference", SqlDbType.NVarChar, 100) { Value = request.ReleaseReference ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@RunStatus", SqlDbType.NVarChar, 30) { Value = SchemaMigrationCreated });
                cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, -1) { Value = request.Notes ?? string.Empty });
                await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
            }

            await AddSchemaExecutionLogAsync(
                cn,
                tx,
                runGuid,
                "CreateRun",
                "Succeeded",
                "Schema comparison run created.",
                JsonSerializer.Serialize(new
                {
                    request.SourceEnvironment,
                    request.TargetEnvironment,
                    request.SourceServerName,
                    request.SourceDatabaseName,
                    request.TargetServerName,
                    request.TargetDatabaseName,
                    request.JiraReference,
                    request.ReleaseReference
                }),
                cancellationToken).ConfigureAwait(false);

            foreach (var bootstrap in new[]
            {
                (DatabaseRole: "Target", Result: targetBootstrap),
                (DatabaseRole: "Source", Result: sourceBootstrap)
            })
            {
                if (!bootstrap.Result.WasApplied)
                {
                    continue;
                }

                await AddSchemaExecutionLogAsync(
                    cn,
                    tx,
                    runGuid,
                    $"Bootstrap{bootstrap.DatabaseRole}",
                    "Applied",
                    $"Schema Migration {bootstrap.DatabaseRole.ToLowerInvariant()} prerequisites were installed from source-controlled SQL.",
                    JsonSerializer.Serialize(new
                    {
                        bootstrap.Result.BootstrapKind,
                        bootstrap.Result.EnvironmentName,
                        DatabaseRole = bootstrap.DatabaseRole,
                        bootstrap.Result.ServerName,
                        bootstrap.Result.DatabaseName,
                        bootstrap.Result.MissingBefore,
                        bootstrap.Result.MissingAfter,
                        bootstrap.Result.InstalledObjects,
                        bootstrap.Result.ScriptSha256,
                        bootstrap.Result.DivergentModules
                    }),
                    cancellationToken).ConfigureAwait(false);
            }

            await tx.CommitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            await tx.RollbackAsync(cancellationToken).ConfigureAwait(false);
            throw;
        }

        return await ReadSchemaRunSummaryAsync(cn, runGuid, cancellationToken).ConfigureAwait(false);
    }

    /// <param name="enforceSourceSyncGate">
    /// True for the workbench (unchanged behaviour): a re-compare is refused unless -SyncSource ran in
    /// the last 30 minutes. The headless deploy path passes false because it always runs -SyncSource
    /// immediately after acceptance, before -WhatIf/-Apply.
    /// </param>
    public async Task CompareAsync(
        string targetServerName,
        string targetDatabaseName,
        Guid runGuid,
        bool enforceSourceSyncGate,
        CancellationToken cancellationToken)
    {
        await using var targetConnection = await OpenTargetSqlAsync(
            targetServerName,
            targetDatabaseName,
            cancellationToken).ConfigureAwait(false);
        var run = await ReadSchemaRunSummaryAsync(targetConnection, runGuid, cancellationToken).ConfigureAwait(false);

        // -SyncSource itself requires a prior Compare (it needs the R7C4-stamped plan to select
        // rows from), so enforcing staleness on a run's very first Compare would make every new
        // run permanently unsatisfiable. Only a re-compare of a run that was already compared
        // before needs a recent -SyncSource, to stop it reusing a since-gone-stale commit.
        var hasComparedBefore = !string.IsNullOrWhiteSpace(run.ComparedOnUtc);
        if (enforceSourceSyncGate && hasComparedBefore && IsSourceSyncStale(run.SourceSyncedOnUtc, DateTime.UtcNow))
        {
            throw new SchemaMigrationException(
                SchemaMigrationErrorKind.FailedPrecondition,
                $"Run {runGuid} has not had its DEV source synchronized into source control within the last 30 minutes. Run -SyncSource for this RunGuid first, then retry Compare.");
        }

        await using var sourceConnection = await OpenSqlForServerDatabaseAsync(
            targetConnection.ConnectionString,
            run.SourceServerName,
            run.SourceDatabaseName,
            cancellationToken).ConfigureAwait(false);

        await EnsureSchemaExclusionInfrastructureAsync(
            "SOURCE",
            run.SourceServerName,
            run.SourceDatabaseName,
            run.SourceEnvironment,
            cancellationToken).ConfigureAwait(false);
        await EnsureSchemaExclusionInfrastructureAsync(
            "TARGET",
            run.TargetServerName,
            run.TargetDatabaseName,
            run.TargetEnvironment,
            cancellationToken).ConfigureAwait(false);

        var sourceIsDevelopment = IsDevelopmentSchemaSource(run.SourceEnvironment, run.SourceDatabaseName);
        var sourceAndTargetAreSameDatabase = AreSameSqlDatabase(sourceConnection, targetConnection);
        var sourcePreDeploymentAttempted = false;
        var targetPreDeploymentAttempted = false;

        try
        {
            if (!sourceIsDevelopment && !sourceAndTargetAreSameDatabase)
            {
                sourcePreDeploymentAttempted = true;
                await ExecuteSchemaMaintenanceProcedureAsync(
                    sourceConnection,
                    SchemaMaintenanceProcedure.PreDeployment,
                    null,
                    cancellationToken).ConfigureAwait(false);
            }

            targetPreDeploymentAttempted = true;
            await ExecuteSchemaMaintenanceProcedureAsync(
                targetConnection,
                SchemaMaintenanceProcedure.PreDeployment,
                null,
                cancellationToken).ConfigureAwait(false);

            var exclusionSync = await SynchronizeSchemaExclusionsAsync(
                sourceConnection,
                targetConnection,
                runGuid,
                cancellationToken).ConfigureAwait(false);
            var sourceObjects = await ReadSchemaSnapshotAsync(sourceConnection, cancellationToken).ConfigureAwait(false);
            var targetObjects = await ReadSchemaSnapshotAsync(targetConnection, cancellationToken).ConfigureAwait(false);
            var lifecycleManagedRecordHistoryTriggerCount = sourceObjects
                .Concat(targetObjects)
                .Where(IsLifecycleManagedRecordHistoryTrigger)
                .Select(x => x.Key)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Count();
            var comparisonRows = BuildSchemaComparisonRows(
                sourceObjects,
                targetObjects,
                exclusionSync.ActiveStableObjectKeys);

            /*
                Comparison snapshots are intentionally captured while the controlled
                pre-deployment lifecycle is active.  Restore every database that this
                request prepared before persisting a successful result.  Cancellation
                must not strand a database in prepared state, hence CancellationToken.None.
            */
            var restorationErrors = await RestoreSchemaComparePreparationAsync(
                sourceConnection,
                targetConnection,
                sourcePreDeploymentAttempted,
                targetPreDeploymentAttempted,
                sourceIsDevelopment,
                sourceAndTargetAreSameDatabase,
                runGuid,
                CancellationToken.None).ConfigureAwait(false);

            if (restorationErrors.Count > 0)
            {
                throw new InvalidOperationException(
                    $"Schema comparison snapshots were captured, but post-deployment restoration failed: {string.Join(" | ", restorationErrors)}");
            }

            sourcePreDeploymentAttempted = false;
            targetPreDeploymentAttempted = false;

            await using var tx = (SqlTransaction)await targetConnection.BeginTransactionAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                await DeactivateSchemaRowsAsync(
                    targetConnection,
                    tx,
                    "SMigration.Schema_ObjectComparisons",
                    runGuid,
                    cancellationToken).ConfigureAwait(false);
                await DeactivateSchemaRowsAsync(
                    targetConnection,
                    tx,
                    "SMigration.Schema_ValidationIssues",
                    runGuid,
                    cancellationToken).ConfigureAwait(false);

                foreach (var row in comparisonRows)
                {
                    await InsertSchemaComparisonRowAsync(targetConnection, tx, runGuid, row, cancellationToken).ConfigureAwait(false);
                }

                var sourcePreparation = sourceIsDevelopment
                    ? "SkippedDevelopmentSource"
                    : sourceAndTargetAreSameDatabase
                        ? "AppliedWithTarget"
                        : "Applied";
                var sourceRestoration = sourceIsDevelopment
                    ? "SkippedDevelopmentSource"
                    : sourceAndTargetAreSameDatabase
                        ? "AppliedWithTarget"
                        : "Applied";

                var summary = new
                {
                    SchemaSnapshotContract,
                    ComparedObjects = comparisonRows.Count,
                    EqualCount = comparisonRows.Count(x => x.DifferenceType == "Equal"),
                    MissingInTargetCount = comparisonRows.Count(x => x.DifferenceType == "MissingInTarget"),
                    MissingInSourceCount = comparisonRows.Count(x => x.DifferenceType == "MissingInSource"),
                    DifferentCount = comparisonRows.Count(x => x.DifferenceType == "Different"),
                    SourcePreDeployment = sourcePreparation,
                    TargetPreDeployment = "Applied",
                    SourcePostDeployment = sourceRestoration,
                    TargetPostDeployment = "Applied",
                    SourceAndTargetAreSameDatabase = sourceAndTargetAreSameDatabase,
                    LifecycleManagedRecordHistoryTriggerCount = lifecycleManagedRecordHistoryTriggerCount,
                    ExcludedObjectCount = exclusionSync.ActiveCount,
                    ExclusionRowsSynchronizedToTarget = exclusionSync.SynchronizedCount,
                    TargetOnlyExclusionsRemoved = exclusionSync.RemovedTargetOnlyCount
                };

                await UpdateSchemaRunStatusAsync(
                    targetConnection,
                    tx,
                    runGuid,
                    SchemaMigrationCompared,
                    compared: true,
                    validated: false,
                    reviewed: false,
                    applied: false,
                    summaryJson: JsonSerializer.Serialize(summary),
                    cancellationToken: cancellationToken).ConfigureAwait(false);

                await AddSchemaExecutionLogAsync(
                    targetConnection,
                    tx,
                    runGuid,
                    "CompareLifecycle",
                    "Succeeded",
                    sourceIsDevelopment
                        ? "The target comparison lifecycle completed through SCore.PreDeploymentScript, snapshot capture and SCore.PostDeploymentScript restoration. Source preparation was skipped because the source environment is DEV."
                        : sourceAndTargetAreSameDatabase
                            ? "The comparison lifecycle completed once through pre-deployment, snapshot capture and post-deployment because source and target resolve to the same SQL database."
                            : "The comparison lifecycle completed through pre-deployment, snapshot capture and post-deployment restoration on both source and target databases.",
                    JsonSerializer.Serialize(new
                    {
                        run.SourceEnvironment,
                        run.SourceServerName,
                        run.SourceDatabaseName,
                        run.TargetEnvironment,
                        run.TargetServerName,
                        run.TargetDatabaseName,
                        SourcePreDeployment = sourcePreparation,
                        TargetPreDeployment = "Applied",
                        SourcePostDeployment = sourceRestoration,
                        TargetPostDeployment = "Applied",
                        SourceAndTargetAreSameDatabase = sourceAndTargetAreSameDatabase
                    }),
                    cancellationToken).ConfigureAwait(false);

                await AddSchemaExecutionLogAsync(
                    targetConnection,
                    tx,
                    runGuid,
                    "ExclusionSync",
                    "Succeeded",
                    $"Source-authoritative schema exclusions were synchronized to the target before comparison. {exclusionSync.ActiveCount} active exclusion(s) were applied to this dataset.",
                    JsonSerializer.Serialize(new
                    {
                        ActiveExcludedObjectCount = exclusionSync.ActiveCount,
                        exclusionSync.SynchronizedCount,
                        exclusionSync.RemovedTargetOnlyCount,
                        SourceDatabase = sourceConnection.Database,
                        TargetDatabase = targetConnection.Database,
                        Scope = "AllDatabases"
                    }),
                    cancellationToken).ConfigureAwait(false);

                await AddSchemaExecutionLogAsync(
                    targetConnection,
                    tx,
                    runGuid,
                    "Compare",
                    "Succeeded",
                    $"Schema comparison completed. {summary.ComparedObjects} objects compared.",
                    JsonSerializer.Serialize(summary),
                    cancellationToken).ConfigureAwait(false);

                await tx.CommitAsync(cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                await tx.RollbackAsync(cancellationToken).ConfigureAwait(false);
                throw;
            }
        }
        catch (Exception compareException)
        {
            var recoveryErrors = await RestoreSchemaComparePreparationAsync(
                sourceConnection,
                targetConnection,
                sourcePreDeploymentAttempted,
                targetPreDeploymentAttempted,
                sourceIsDevelopment,
                sourceAndTargetAreSameDatabase,
                runGuid,
                CancellationToken.None).ConfigureAwait(false);

            if (recoveryErrors.Count > 0)
            {
                throw new InvalidOperationException(
                    $"Schema comparison failed after pre-deployment preparation. Post-deployment recovery also failed: {string.Join(" | ", recoveryErrors)}",
                    compareException);
            }

            throw;
        }
    }

    public async Task<SchemaValidationResult> ValidateAsync(
        string targetServerName,
        string targetDatabaseName,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        await using var cn = await OpenTargetSqlAsync(targetServerName, targetDatabaseName, cancellationToken).ConfigureAwait(false);
        var rows = await ReadSchemaComparisonRowsAsync(
            cn,
            runGuid,
            string.Empty,
            string.Empty,
            string.Empty,
            // Validation evaluates the persisted declarative definition contracts. The list UI
            // deliberately omits the large definitions, but validation must load them or every
            // current constraint/table/index snapshot is indistinguishable from a legacy row.
            includeDefinitions: true,
            comparisonGuid: null,
            cancellationToken).ConfigureAwait(false);
        var validationScopeRows = rows.Where(x => x.IsSelected).ToList();
        await using var tx = (SqlTransaction)await cn.BeginTransactionAsync(cancellationToken).ConfigureAwait(false);

        try
        {
            await DeactivateSchemaRowsAsync(
                cn,
                tx,
                "SMigration.Schema_ValidationIssues",
                runGuid,
                cancellationToken).ConfigureAwait(false);

            var issues = BuildSchemaValidationIssues(validationScopeRows, rows.Count > 0);
            foreach (var issue in issues)
            {
                await InsertSchemaValidationIssueAsync(cn, tx, runGuid, issue, cancellationToken).ConfigureAwait(false);
            }

            var status = issues.Any(x => x.Severity.Equals("Fail", StringComparison.OrdinalIgnoreCase))
                ? SchemaMigrationValidationFailed
                : SchemaMigrationValidated;

            await UpdateSchemaRunStatusAsync(
                cn,
                tx,
                runGuid,
                status,
                compared: false,
                validated: true,
                reviewed: false,
                applied: false,
                summaryJson: null,
                cancellationToken: cancellationToken).ConfigureAwait(false);

            var validationFailCount = issues.Count(x => x.Severity == "Fail");
            var validationWarnCount = issues.Count(x => x.Severity == "Warn");
            var validationInfoCount = issues.Count(x => x.Severity == "Info");

            await AddSchemaExecutionLogAsync(
                cn,
                tx,
                runGuid,
                "Validate",
                validationFailCount > 0 ? "Failed" : "Succeeded",
                $"Schema validation completed for the explicit saved selection containing {validationScopeRows.Count} row(s), with {validationFailCount} fail(s), {validationWarnCount} warning(s), and {validationInfoCount} information item(s).",
                JsonSerializer.Serialize(new
                {
                    ScopeMode = "ExplicitSelection",
                    ScopedRowCount = validationScopeRows.Count,
                    FailCount = validationFailCount,
                    WarnCount = validationWarnCount,
                    InfoCount = validationInfoCount
                }),
                cancellationToken).ConfigureAwait(false);

            await tx.CommitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            await tx.RollbackAsync(cancellationToken).ConfigureAwait(false);
            throw;
        }

        return await ReadSchemaValidationAsync(cn, runGuid, cancellationToken).ConfigureAwait(false);
    }

    /// <summary>Headless convenience: select exactly <paramref name="comparisonGuids"/> (no reference-data copy).</summary>
    public Task<SchemaSelectionCounts> SaveSelectionAsync(
        string targetServerName,
        string targetDatabaseName,
        Guid runGuid,
        IReadOnlyCollection<Guid> comparisonGuids,
        string notes,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(comparisonGuids);
        var selections = comparisonGuids
            .Select(x => new SchemaSelectionRequestItem { ComparisonGuid = x.ToString(), IsSelected = true })
            .ToList();
        return SaveSelectionAsync(targetServerName, targetDatabaseName, runGuid, selections, notes, cancellationToken);
    }

    public async Task<SchemaSelectionCounts> SaveSelectionAsync(
        string targetServerName,
        string targetDatabaseName,
        Guid runGuid,
        IReadOnlyList<SchemaSelectionRequestItem> requestSelections,
        string notes,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requestSelections);

        await using var cn = await OpenTargetSqlAsync(targetServerName, targetDatabaseName, cancellationToken).ConfigureAwait(false);
        var currentRows = await ReadSchemaComparisonRowsAsync(
            cn,
            runGuid,
            string.Empty,
            string.Empty,
            string.Empty,
            includeDefinitions: false,
            comparisonGuid: null,
            cancellationToken).ConfigureAwait(false);
        var deployableRows = currentRows
            .Where(x => x.IsDeployable && !x.DifferenceType.Equals("Equal", StringComparison.OrdinalIgnoreCase))
            .ToList();

        var selectedComparisonGuids = requestSelections
            .Where(x => x.IsSelected && Guid.TryParse(x.ComparisonGuid, out _))
            .Select(x => Guid.Parse(x.ComparisonGuid))
            .ToHashSet();

        // CYB-566: "Copy reference data" is honoured only for a selected brand-new table.
        var copyReferenceDataComparisonGuids = requestSelections
            .Where(x => x.IsSelected && x.CopyReferenceData && Guid.TryParse(x.ComparisonGuid, out _))
            .Select(x => Guid.Parse(x.ComparisonGuid))
            .ToHashSet();

        // Backward compatibility for pre-R22 clients that supplied full object keys.
        var legacySelectionByKey = requestSelections
            .Where(x => !string.IsNullOrWhiteSpace(x.ObjectType))
            .GroupBy(x => BuildSchemaSelectionKey(x), StringComparer.OrdinalIgnoreCase)
            .ToDictionary(x => x.Key, x => x.Last().IsSelected, StringComparer.OrdinalIgnoreCase);

        var usesGuidOnlySelection = requestSelections.Count == 0 || requestSelections.All(x => string.IsNullOrWhiteSpace(x.ObjectType));
        var selections = deployableRows
            .Select(row =>
            {
                var comparisonGuid = Guid.TryParse(row.ComparisonGuid, out var parsedComparisonGuid)
                    ? parsedComparisonGuid
                    : Guid.Empty;
                var isSelected = usesGuidOnlySelection
                    ? selectedComparisonGuids.Contains(comparisonGuid)
                    : legacySelectionByKey.TryGetValue(BuildSchemaSelectionKey(row), out var legacySelected) && legacySelected;

                return new SchemaSelectionDraft
                {
                    ComparisonGuid = comparisonGuid,
                    ObjectType = row.ObjectType,
                    SchemaName = row.SchemaName,
                    ObjectName = row.ObjectName,
                    ParentObjectName = row.ParentObjectName,
                    IsSelected = isSelected,
                    IsDestructiveRisk = row.IsDestructiveRisk,
                    IsNewTable = IsNewTableComparison(row.ObjectType, row.DifferenceType),
                    CopyReferenceData = isSelected
                        && IsNewTableComparison(row.ObjectType, row.DifferenceType)
                        && copyReferenceDataComparisonGuids.Contains(comparisonGuid)
                };
            })
            .ToList();

        // CYB-566: the schema runner never connects to the source, so for every selected new
        // table the source's column order (catalog only) - plus its rows when "Copy reference
        // data" is ticked - is captured here, read-only, and carried on the selection row into
        // the accepted plan. -SyncSource then generates the table's canonical create file from it.
        if (selections.Any(x => x.IsSelected && x.IsNewTable))
        {
            var run = await ReadSchemaRunSummaryAsync(cn, runGuid, cancellationToken).ConfigureAwait(false);
            await using var sourceConnection = await OpenSqlForServerDatabaseAsync(
                cn.ConnectionString,
                run.SourceServerName,
                run.SourceDatabaseName,
                cancellationToken).ConfigureAwait(false);

            foreach (var selection in selections.Where(x => x.IsSelected && x.IsNewTable))
            {
                selection.NewTableCaptureJson = await ReadSchemaNewTableCaptureJsonAsync(
                    sourceConnection,
                    selection.SchemaName,
                    selection.ObjectName,
                    selection.CopyReferenceData,
                    cancellationToken).ConfigureAwait(false);
            }
        }

        await using var tx = (SqlTransaction)await cn.BeginTransactionAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await DeactivateSchemaRowsAsync(cn, tx, "SMigration.Schema_RunSelections", runGuid, cancellationToken).ConfigureAwait(false);
            await InvalidateSchemaValidationAndReviewAsync(cn, tx, runGuid, cancellationToken).ConfigureAwait(false);

            foreach (var selection in selections.Where(x => x.IsSelected))
            {
                await InsertSchemaSelectionRowAsync(cn, tx, runGuid, selection, cancellationToken).ConfigureAwait(false);
            }

            await AddSchemaExecutionLogAsync(
                cn,
                tx,
                runGuid,
                "Selection",
                "Saved",
                "Schema deployment selection saved. Validation and deployment acceptance were reset because the plan changed.",
                JsonSerializer.Serialize(new
                {
                    Notes = notes,
                    SelectedCount = selections.Count(x => x.IsSelected),
                    DeployableCount = selections.Count,
                    ExplicitSelectionCount = selections.Count(x => x.IsSelected),
                    CopyReferenceDataTables = selections
                        .Where(x => x.CopyReferenceData)
                        .Select(x => $"{x.SchemaName}.{x.ObjectName}")
                        .ToArray()
                }),
                cancellationToken).ConfigureAwait(false);

            await tx.CommitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            await tx.RollbackAsync(cancellationToken).ConfigureAwait(false);
            throw;
        }

        return await ReadSchemaSelectionCountsAsync(cn, runGuid, cancellationToken).ConfigureAwait(false);
    }

    /// <summary>
    /// Records deployment acceptance (the workbench "Accept" / review step). Initial acceptance is only
    /// allowed from Validated with no Fail issues; an already-accepted unchanged plan may have its
    /// acceptance note updated.
    /// </summary>
    public async Task<SchemaOperationResult> AcceptAsync(
        string targetServerName,
        string targetDatabaseName,
        Guid runGuid,
        string reviewedByNote,
        CancellationToken cancellationToken)
    {
        await using var cn = await OpenTargetSqlAsync(targetServerName, targetDatabaseName, cancellationToken).ConfigureAwait(false);
        var run = await ReadSchemaRunSummaryAsync(cn, runGuid, cancellationToken).ConfigureAwait(false);
        var isInitialAcceptance = run.RunStatus.Equals(SchemaMigrationValidated, StringComparison.OrdinalIgnoreCase);
        var isAcceptanceUpdate = run.IsReviewed
            && run.RunStatus.Equals(SchemaMigrationReviewed, StringComparison.OrdinalIgnoreCase);
        reviewedByNote = (reviewedByNote ?? string.Empty).Trim();

        if (!isInitialAcceptance && !isAcceptanceUpdate)
        {
            return new SchemaOperationResult(
                false,
                "Schema acceptance can only be recorded after validation or updated while the unchanged plan remains in Reviewed status.");
        }

        if (isAcceptanceUpdate && string.IsNullOrWhiteSpace(reviewedByNote))
        {
            return new SchemaOperationResult(
                false,
                "Enter an additional acceptance note before updating an already accepted schema run.");
        }

        var validation = await ReadSchemaValidationAsync(cn, runGuid, cancellationToken).ConfigureAwait(false);
        if (validation.FailCount > 0)
        {
            return new SchemaOperationResult(
                false,
                "Schema review cannot be completed while validation failures exist.");
        }

        await using var tx = (SqlTransaction)await cn.BeginTransactionAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await using (var cmd = new SqlCommand(@"
UPDATE SMigration.Schema_Run
SET
    IsReviewed = 1,
    ReviewedOnUtc = SYSUTCDATETIME(),
    ReviewedByUserId = ISNULL(SCore.GetCurrentUserId(), -1),
    RunStatus = @RunStatus,
    Notes = CASE WHEN LEN(@ReviewedByNote) > 0 THEN CONCAT(Notes, CHAR(10), @ReviewedByNote) ELSE Notes END
WHERE Guid = @RunGuid
  AND RowStatus <> 0
  AND RowStatus <> 254;", cn, tx)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 300
            })
            {
                cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
                cmd.Parameters.Add(new SqlParameter("@RunStatus", SqlDbType.NVarChar, 30) { Value = SchemaMigrationReviewed });
                cmd.Parameters.Add(new SqlParameter("@ReviewedByNote", SqlDbType.NVarChar, -1) { Value = reviewedByNote });
                await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
            }

            await AddSchemaExecutionLogAsync(
                cn,
                tx,
                runGuid,
                isAcceptanceUpdate ? "AcceptanceUpdate" : "Review",
                "Succeeded",
                isAcceptanceUpdate
                    ? "Schema deployment acceptance note updated for the unchanged validated plan."
                    : "Schema comparison and validation have been reviewed and accepted for deployment.",
                JsonSerializer.Serialize(new
                {
                    AcceptanceMode = isAcceptanceUpdate ? "Update" : "Initial",
                    ReviewedByNote = reviewedByNote,
                    PreviousReviewedOnUtc = run.ReviewedOnUtc
                }),
                cancellationToken).ConfigureAwait(false);

            await tx.CommitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            await tx.RollbackAsync(cancellationToken).ConfigureAwait(false);
            throw;
        }

        return new SchemaOperationResult(
            true,
            isAcceptanceUpdate
                ? "Schema deployment acceptance note updated. The accepted plan is unchanged and remains ready for the controlled runner or worker."
                : "Schema review completed and accepted for deployment. Deployment must still be performed through the approved source-controlled schema deployment process.");
    }

    public async Task<SchemaRunRecord> ReadRunAsync(
        string targetServerName,
        string targetDatabaseName,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        await using var cn = await OpenTargetSqlAsync(targetServerName, targetDatabaseName, cancellationToken).ConfigureAwait(false);
        return await ReadSchemaRunSummaryAsync(cn, runGuid, cancellationToken).ConfigureAwait(false);
    }

    /// <summary>
    /// Newest active run on the target that is accepted (Reviewed, IsReviewed = 1), not yet applied,
    /// and was prepared for the same target server/database and source database; null when none
    /// exists or the target has no Schema Migration workbench yet.
    /// </summary>
    public async Task<SchemaAcceptedRunInfo?> FindAcceptedUnappliedRunAsync(
        string targetServerName,
        string targetDatabaseName,
        string sourceDatabaseName,
        CancellationToken cancellationToken)
    {
        await using var cn = await OpenTargetSqlAsync(targetServerName, targetDatabaseName, cancellationToken).ConfigureAwait(false);
        await using var cmd = new SqlCommand(@"
IF OBJECT_ID(N'SMigration.Schema_Run', N'U') IS NOT NULL
BEGIN
    SELECT TOP (1)
        r.Guid,
        r.ComparedOnUtc
    FROM SMigration.Schema_Run AS r
    WHERE r.RowStatus NOT IN (0, 254)
      AND r.RunStatus = N'Reviewed'
      AND r.IsReviewed = 1
      AND r.AppliedOnUtc IS NULL
      AND LTRIM(RTRIM(r.TargetServerName)) = @TargetServerName
      AND LTRIM(RTRIM(r.TargetDatabaseName)) = @TargetDatabaseName
      AND LTRIM(RTRIM(r.SourceDatabaseName)) = @SourceDatabaseName
    ORDER BY r.ID DESC;
END;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@TargetServerName", SqlDbType.NVarChar, 255) { Value = (targetServerName ?? string.Empty).Trim() });
        cmd.Parameters.Add(new SqlParameter("@TargetDatabaseName", SqlDbType.NVarChar, 255) { Value = (targetDatabaseName ?? string.Empty).Trim() });
        cmd.Parameters.Add(new SqlParameter("@SourceDatabaseName", SqlDbType.NVarChar, 255) { Value = (sourceDatabaseName ?? string.Empty).Trim() });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        if (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            return new SchemaAcceptedRunInfo(
                reader.GetGuid(0),
                reader.IsDBNull(1) ? null : DateTime.SpecifyKind(reader.GetDateTime(1), DateTimeKind.Utc));
        }

        return null;
    }

    /// <summary>
    /// Reads comparison rows through the same (TOP 5000, exclusion-filtered) query the workbench uses.
    /// <see cref="SchemaComparisonRowsPage.MayBeTruncated"/> is true when the cap was reached.
    /// </summary>
    public async Task<SchemaComparisonRowsPage> ListComparisonRowsAsync(
        string targetServerName,
        string targetDatabaseName,
        Guid runGuid,
        string differenceType,
        bool includeDefinitions,
        CancellationToken cancellationToken)
    {
        await using var cn = await OpenTargetSqlAsync(targetServerName, targetDatabaseName, cancellationToken).ConfigureAwait(false);
        var rows = await ReadSchemaComparisonRowsAsync(
            cn,
            runGuid,
            string.Empty,
            differenceType ?? string.Empty,
            string.Empty,
            includeDefinitions,
            comparisonGuid: null,
            cancellationToken).ConfigureAwait(false);
        return new SchemaComparisonRowsPage(rows, rows.Count >= SchemaComparisonRowReadLimit);
    }

    /// <summary>The fixed TOP (5000) cap of <see cref="ReadSchemaComparisonRowsAsync"/>.</summary>
    public const int SchemaComparisonRowReadLimit = 5000;

    private async Task<SqlConnection> OpenSqlAsync(CancellationToken cancellationToken)
    {
        var cn = new SqlConnection(_templateConnectionString);
        try
        {
            await cn.OpenAsync(cancellationToken).ConfigureAwait(false);
            return cn;
        }
        catch
        {
            await cn.DisposeAsync().ConfigureAwait(false);
            throw;
        }
    }

    private static async Task<SqlConnection> OpenSqlForServerDatabaseAsync(
        string baseConnectionString,
        string serverName,
        string databaseName,
        CancellationToken cancellationToken)
    {
        var builder = new SqlConnectionStringBuilder(baseConnectionString);

        if (!string.IsNullOrWhiteSpace(serverName))
        {
            builder.DataSource = serverName;
        }

        if (!string.IsNullOrWhiteSpace(databaseName))
        {
            builder.InitialCatalog = databaseName;
        }

        var cn = new SqlConnection(builder.ConnectionString);
        await cn.OpenAsync(cancellationToken).ConfigureAwait(false);
        return cn;
    }
}
