using Concursus.API.Core;
using Grpc.Core;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Concursus.API.Services;

public partial class CoreService
{
    private const string SchemaMigrationCreated = "Created";
    private const string SchemaMigrationCompared = "Compared";
    private const string SchemaMigrationValidated = "Validated";
    private const string SchemaMigrationReviewed = "Reviewed";
    private const string SchemaMigrationDeploymentRecorded = "DeploymentRecorded";

    public override async Task<SchemaMigrationRunResponse> SchemaMigrationRunCreate(
        SchemaMigrationRunCreateRequest request,
        ServerCallContext context)
    {
        if (string.IsNullOrWhiteSpace(request.SourceDatabaseName))
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, "Source database is required."));
        }

        if (string.IsNullOrWhiteSpace(request.TargetDatabaseName))
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, "Target database is required."));
        }

        try
        {
            await using var templateConnection = await OpenSqlAsync(context.CancellationToken).ConfigureAwait(false);
            await using var cn = await OpenSqlForServerDatabaseAsync(
                templateConnection.ConnectionString,
                request.TargetServerName,
                request.TargetDatabaseName,
                context.CancellationToken).ConfigureAwait(false);

            var missingBootstrapObjects = await ReadSchemaMigrationBootstrapMissingObjectsAsync(
                cn,
                context.CancellationToken).ConfigureAwait(false);

            if (missingBootstrapObjects.Count > 0)
            {
                var targetServer = string.IsNullOrWhiteSpace(request.TargetServerName)
                    ? cn.DataSource
                    : request.TargetServerName.Trim();
                var targetDatabase = string.IsNullOrWhiteSpace(request.TargetDatabaseName)
                    ? cn.Database
                    : request.TargetDatabaseName.Trim();
                var missingObjects = string.Join(", ", missingBootstrapObjects);

                throw new RpcException(new Status(
                    StatusCode.FailedPrecondition,
                    $"SCHEMA_MIGRATION_BOOTSTRAP_REQUIRED|The Schema Migration workbench is not initialised in target '{targetServer} / {targetDatabase}'. Missing: {missingObjects}. Run tools/SchemaDeployment/Initialize-CymBuildSchemaMigration.ps1 from a controlled deployment account, then retry Create Run."));
            }

            var runGuid = Guid.NewGuid();
            await using var tx = (SqlTransaction)await cn.BeginTransactionAsync(context.CancellationToken).ConfigureAwait(false);

            try
            {
                await EnsureSchemaDataObjectAsync(cn, tx, runGuid, "SMigration", "Schema_Run", context.CancellationToken).ConfigureAwait(false);

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
                    cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 2000) { Value = request.Notes ?? string.Empty });
                    await cmd.ExecuteNonQueryAsync(context.CancellationToken).ConfigureAwait(false);
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
                    context.CancellationToken).ConfigureAwait(false);

                await tx.CommitAsync(context.CancellationToken).ConfigureAwait(false);
            }
            catch
            {
                await tx.RollbackAsync(context.CancellationToken).ConfigureAwait(false);
                throw;
            }

            return new SchemaMigrationRunResponse
            {
                Run = await ReadSchemaRunSummaryAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false)
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Schema run create SQL failed: {ex.Message}"));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new RpcException(new Status(StatusCode.Internal, $"Schema run create failed: {ex.Message}"));
        }
    }

    public override async Task<SchemaMigrationRunsResponse> SchemaMigrationRuns(
        SchemaMigrationRunsRequest request,
        ServerCallContext context)
    {
        var response = new SchemaMigrationRunsResponse();
        var top = request.Top <= 0 ? 50 : Math.Min(request.Top, 200);

        await using var cn = await OpenSchemaTargetSqlAsync(request.TargetServerName, request.TargetDatabaseName, context.CancellationToken).ConfigureAwait(false);
        await using var cmd = new SqlCommand(@"
SELECT TOP (@Top)
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
    r.SummaryJson
FROM SMigration.Schema_Run AS r
WHERE r.RowStatus <> 0
  AND r.RowStatus <> 254
ORDER BY r.ID DESC;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@Top", SqlDbType.Int) { Value = top });

        await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(context.CancellationToken).ConfigureAwait(false))
        {
            response.Runs.Add(MapSchemaRunSummary(reader));
        }

        return response;
    }

    public override async Task<SchemaMigrationRunResponse> SchemaMigrationRunGet(
        SchemaMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        await using var cn = await OpenSchemaTargetSqlAsync(request.TargetServerName, request.TargetDatabaseName, context.CancellationToken).ConfigureAwait(false);
        return new SchemaMigrationRunResponse
        {
            Run = await ReadSchemaRunSummaryAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false)
        };
    }

    public override async Task<SchemaMigrationDashboardResponse> SchemaMigrationCompare(
        SchemaMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var targetConnection = await OpenSchemaTargetSqlAsync(
                request.TargetServerName,
                request.TargetDatabaseName,
                context.CancellationToken).ConfigureAwait(false);
            var run = await ReadSchemaRunSummaryAsync(targetConnection, runGuid, context.CancellationToken).ConfigureAwait(false);

            await using var sourceConnection = await OpenSqlForServerDatabaseAsync(
                targetConnection.ConnectionString,
                run.SourceServerName,
                run.SourceDatabaseName,
                context.CancellationToken).ConfigureAwait(false);

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
                        context.CancellationToken).ConfigureAwait(false);
                }

                targetPreDeploymentAttempted = true;
                await ExecuteSchemaMaintenanceProcedureAsync(
                    targetConnection,
                    SchemaMaintenanceProcedure.PreDeployment,
                    context.CancellationToken).ConfigureAwait(false);

                var sourceObjects = await ReadSchemaSnapshotAsync(sourceConnection, context.CancellationToken).ConfigureAwait(false);
                var targetObjects = await ReadSchemaSnapshotAsync(targetConnection, context.CancellationToken).ConfigureAwait(false);
                var comparisonRows = BuildSchemaComparisonRows(sourceObjects, targetObjects);

                await using var tx = (SqlTransaction)await targetConnection.BeginTransactionAsync(context.CancellationToken).ConfigureAwait(false);
                try
                {
                    await DeactivateSchemaRowsAsync(
                        targetConnection,
                        tx,
                        "SMigration.Schema_ObjectComparisons",
                        runGuid,
                        context.CancellationToken).ConfigureAwait(false);
                    await DeactivateSchemaRowsAsync(
                        targetConnection,
                        tx,
                        "SMigration.Schema_ValidationIssues",
                        runGuid,
                        context.CancellationToken).ConfigureAwait(false);

                    foreach (var row in comparisonRows)
                    {
                        await InsertSchemaComparisonRowAsync(targetConnection, tx, runGuid, row, context.CancellationToken).ConfigureAwait(false);
                    }

                    var sourcePreparation = sourceIsDevelopment
                        ? "SkippedDevelopmentSource"
                        : sourceAndTargetAreSameDatabase
                            ? "AppliedWithTarget"
                            : "Applied";

                    var summary = new
                    {
                        ComparedObjects = comparisonRows.Count,
                        EqualCount = comparisonRows.Count(x => x.DifferenceType == "Equal"),
                        MissingInTargetCount = comparisonRows.Count(x => x.DifferenceType == "MissingInTarget"),
                        MissingInSourceCount = comparisonRows.Count(x => x.DifferenceType == "MissingInSource"),
                        DifferentCount = comparisonRows.Count(x => x.DifferenceType == "Different"),
                        SourcePreDeployment = sourcePreparation,
                        TargetPreDeployment = "Applied",
                        SourceAndTargetAreSameDatabase = sourceAndTargetAreSameDatabase
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
                        cancellationToken: context.CancellationToken).ConfigureAwait(false);

                    await AddSchemaExecutionLogAsync(
                        targetConnection,
                        tx,
                        runGuid,
                        "ComparePreDeployment",
                        "Succeeded",
                        sourceIsDevelopment
                            ? "SCore.PreDeploymentScript completed on the target database. Source preparation was skipped because the source environment is DEV."
                            : sourceAndTargetAreSameDatabase
                                ? "SCore.PreDeploymentScript completed once because source and target resolve to the same SQL database."
                                : "SCore.PreDeploymentScript completed on both source and target databases before comparison.",
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
                            SourceAndTargetAreSameDatabase = sourceAndTargetAreSameDatabase
                        }),
                        context.CancellationToken).ConfigureAwait(false);

                    await AddSchemaExecutionLogAsync(
                        targetConnection,
                        tx,
                        runGuid,
                        "Compare",
                        "Succeeded",
                        $"Schema comparison completed. {summary.ComparedObjects} objects compared.",
                        JsonSerializer.Serialize(summary),
                        context.CancellationToken).ConfigureAwait(false);

                    await tx.CommitAsync(context.CancellationToken).ConfigureAwait(false);
                }
                catch
                {
                    await tx.RollbackAsync(context.CancellationToken).ConfigureAwait(false);
                    throw;
                }

                return new SchemaMigrationDashboardResponse
                {
                    Dashboard = await ReadSchemaDashboardAsync(targetConnection, runGuid, context.CancellationToken).ConfigureAwait(false)
                };
            }
            catch (Exception compareException)
            {
                var recoveryErrors = await RestoreSchemaComparePreparationAfterFailureAsync(
                    sourceConnection,
                    targetConnection,
                    sourcePreDeploymentAttempted,
                    targetPreDeploymentAttempted,
                    sourceIsDevelopment,
                    sourceAndTargetAreSameDatabase,
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
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Schema compare SQL failed: {ex.Message}"));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            var message = ex.InnerException is null ? ex.Message : $"{ex.Message} Inner: {ex.InnerException.Message}";
            throw new RpcException(new Status(StatusCode.Internal, $"Schema compare failed: {message}"));
        }
    }

    public override async Task<SchemaMigrationValidateResponse> SchemaMigrationValidate(
        SchemaMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenSchemaTargetSqlAsync(request.TargetServerName, request.TargetDatabaseName, context.CancellationToken).ConfigureAwait(false);
            var rows = await ReadSchemaComparisonRowsAsync(
                cn,
                runGuid,
                string.Empty,
                string.Empty,
                string.Empty,
                includeDefinitions: false,
                comparisonGuid: null,
                context.CancellationToken).ConfigureAwait(false);
            var hasExplicitSelection = rows.Any(x => x.HasExplicitSelection);
            var validationScopeRows = hasExplicitSelection
                ? rows.Where(x => x.IsSelected).ToList()
                : rows.Where(x => x.IsDeployable && !x.DifferenceType.Equals("Equal", StringComparison.OrdinalIgnoreCase)).ToList();
            await using var tx = (SqlTransaction)await cn.BeginTransactionAsync(context.CancellationToken).ConfigureAwait(false);

            try
            {
                await DeactivateSchemaRowsAsync(
                    cn,
                    tx,
                    "SMigration.Schema_ValidationIssues",
                    runGuid,
                    context.CancellationToken).ConfigureAwait(false);

                var issues = BuildSchemaValidationIssues(validationScopeRows);
                foreach (var issue in issues)
                {
                    await InsertSchemaValidationIssueAsync(cn, tx, runGuid, issue, context.CancellationToken).ConfigureAwait(false);
                }

                var status = issues.Any(x => x.Severity.Equals("Fail", StringComparison.OrdinalIgnoreCase))
                    ? "ValidationFailed"
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
                    cancellationToken: context.CancellationToken).ConfigureAwait(false);

                var validationFailCount = issues.Count(x => x.Severity == "Fail");
                var validationWarnCount = issues.Count(x => x.Severity == "Warn");
                var validationInfoCount = issues.Count(x => x.Severity == "Info");

                await AddSchemaExecutionLogAsync(
                    cn,
                    tx,
                    runGuid,
                    "Validate",
                    validationFailCount > 0 ? "Failed" : "Succeeded",
                    $"Schema validation completed for {(hasExplicitSelection ? "the explicit saved selection" : "the default-all deployable plan")} containing {validationScopeRows.Count} row(s), with {validationFailCount} fail(s), {validationWarnCount} warning(s), and {validationInfoCount} information item(s).",
                    JsonSerializer.Serialize(new
                    {
                        ScopeMode = hasExplicitSelection ? "ExplicitSelection" : "DefaultAllDeployable",
                        ScopedRowCount = validationScopeRows.Count,
                        FailCount = validationFailCount,
                        WarnCount = validationWarnCount,
                        InfoCount = validationInfoCount
                    }),
                    context.CancellationToken).ConfigureAwait(false);

                await tx.CommitAsync(context.CancellationToken).ConfigureAwait(false);
            }
            catch
            {
                await tx.RollbackAsync(context.CancellationToken).ConfigureAwait(false);
                throw;
            }

            return await ReadSchemaValidationResponseAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false);
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Schema validate SQL failed: {ex.Message}"));
        }
    }

    public override async Task<SchemaMigrationDashboardResponse> SchemaMigrationDashboard(
        SchemaMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        await using var cn = await OpenSchemaTargetSqlAsync(request.TargetServerName, request.TargetDatabaseName, context.CancellationToken).ConfigureAwait(false);
        return new SchemaMigrationDashboardResponse
        {
            Dashboard = await ReadSchemaDashboardAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false)
        };
    }

    public override async Task<SchemaMigrationObjectsResponse> SchemaMigrationObjects(
        SchemaMigrationObjectsRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        Guid? comparisonGuid = null;
        if (!string.IsNullOrWhiteSpace(request.ComparisonGuid))
        {
            comparisonGuid = ParseGuid(request.ComparisonGuid, "comparisonGuid");
        }

        await using var cn = await OpenSchemaTargetSqlAsync(request.TargetServerName, request.TargetDatabaseName, context.CancellationToken).ConfigureAwait(false);
        var response = new SchemaMigrationObjectsResponse();
        response.Rows.AddRange(await ReadSchemaComparisonRowsAsync(
            cn,
            runGuid,
            request.ObjectType,
            request.DifferenceType,
            request.SearchText,
            request.IncludeDefinitions,
            comparisonGuid,
            context.CancellationToken).ConfigureAwait(false));
        return response;
    }

    public override async Task<SchemaMigrationSelectionResponse> SchemaMigrationSelectionClear(
        SchemaMigrationSelectionClearRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenSchemaTargetSqlAsync(request.TargetServerName, request.TargetDatabaseName, context.CancellationToken).ConfigureAwait(false);
            await using var tx = (SqlTransaction)await cn.BeginTransactionAsync(context.CancellationToken).ConfigureAwait(false);
            try
            {
                await DeactivateSchemaRowsAsync(
                    cn,
                    tx,
                    "SMigration.Schema_RunSelections",
                    runGuid,
                    context.CancellationToken).ConfigureAwait(false);
                await InvalidateSchemaValidationAndReviewAsync(cn, tx, runGuid, context.CancellationToken).ConfigureAwait(false);

                await AddSchemaExecutionLogAsync(
                    cn,
                    tx,
                    runGuid,
                    "Selection",
                    "Cleared",
                    "Schema deployment selection cleared. The plan returned to default-all; validation and deployment acceptance were reset.",
                    JsonSerializer.Serialize(new { request.Notes }),
                    context.CancellationToken).ConfigureAwait(false);

                await tx.CommitAsync(context.CancellationToken).ConfigureAwait(false);
            }
            catch
            {
                await tx.RollbackAsync(context.CancellationToken).ConfigureAwait(false);
                throw;
            }

            var counts = await ReadSchemaSelectionCountsAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false);
            return new SchemaMigrationSelectionResponse
            {
                Success = true,
                Message = "Selection cleared. All deployable schema differences will be included by default. Revalidate and accept the updated plan before deployment.",
                SelectedCount = counts.SelectedCount,
                DeployableCount = counts.DeployableCount,
                ExplicitSelectionCount = counts.ExplicitSelectionCount
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Schema selection clear SQL failed: {ex.Message}"));
        }
    }

    public override async Task<SchemaMigrationSelectionResponse> SchemaMigrationSelectionSave(
        SchemaMigrationSelectionSaveRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenSchemaTargetSqlAsync(request.TargetServerName, request.TargetDatabaseName, context.CancellationToken).ConfigureAwait(false);
            var currentRows = await ReadSchemaComparisonRowsAsync(
                cn,
                runGuid,
                string.Empty,
                string.Empty,
                string.Empty,
                includeDefinitions: false,
                comparisonGuid: null,
                context.CancellationToken).ConfigureAwait(false);
            var deployableRows = currentRows
                .Where(x => x.IsDeployable && !x.DifferenceType.Equals("Equal", StringComparison.OrdinalIgnoreCase))
                .ToList();

            var selectedComparisonGuids = request.Selections
                .Where(x => x.IsSelected && Guid.TryParse(x.ComparisonGuid, out _))
                .Select(x => Guid.Parse(x.ComparisonGuid))
                .ToHashSet();

            // Backward compatibility for pre-R22 clients that supplied full object keys.
            var legacySelectionByKey = request.Selections
                .Where(x => !string.IsNullOrWhiteSpace(x.ObjectType))
                .GroupBy(x => BuildSchemaSelectionKey(x), StringComparer.OrdinalIgnoreCase)
                .ToDictionary(x => x.Key, x => x.Last().IsSelected, StringComparer.OrdinalIgnoreCase);

            var usesGuidOnlySelection = request.Selections.Count == 0 || request.Selections.All(x => string.IsNullOrWhiteSpace(x.ObjectType));
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
                        IsSelected = isSelected
                    };
                })
                .ToList();

            if (selections.Count == 0 || selections.All(x => x.IsSelected))
            {
                await using var clearTx = (SqlTransaction)await cn.BeginTransactionAsync(context.CancellationToken).ConfigureAwait(false);
                try
                {
                    await DeactivateSchemaRowsAsync(cn, clearTx, "SMigration.Schema_RunSelections", runGuid, context.CancellationToken).ConfigureAwait(false);
                    await InvalidateSchemaValidationAndReviewAsync(cn, clearTx, runGuid, context.CancellationToken).ConfigureAwait(false);
                    await AddSchemaExecutionLogAsync(
                        cn,
                        clearTx,
                        runGuid,
                        "Selection",
                        "DefaultAll",
                        "Schema deployment selection saved as default-all. Validation and deployment acceptance were reset because the plan changed.",
                        JsonSerializer.Serialize(new { request.Notes, DeployableCount = selections.Count }),
                        context.CancellationToken).ConfigureAwait(false);
                    await clearTx.CommitAsync(context.CancellationToken).ConfigureAwait(false);
                }
                catch
                {
                    await clearTx.RollbackAsync(context.CancellationToken).ConfigureAwait(false);
                    throw;
                }

                var defaultCounts = await ReadSchemaSelectionCountsAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false);
                return new SchemaMigrationSelectionResponse
                {
                    Success = true,
                    Message = "All deployable schema differences are selected, so the persisted configuration remains default-all. Revalidate and accept the updated plan before deployment.",
                    SelectedCount = defaultCounts.SelectedCount,
                    DeployableCount = defaultCounts.DeployableCount,
                    ExplicitSelectionCount = defaultCounts.ExplicitSelectionCount
                };
            }

            await using var tx = (SqlTransaction)await cn.BeginTransactionAsync(context.CancellationToken).ConfigureAwait(false);
            try
            {
                await DeactivateSchemaRowsAsync(cn, tx, "SMigration.Schema_RunSelections", runGuid, context.CancellationToken).ConfigureAwait(false);
                await InvalidateSchemaValidationAndReviewAsync(cn, tx, runGuid, context.CancellationToken).ConfigureAwait(false);

                foreach (var selection in selections)
                {
                    await InsertSchemaSelectionRowAsync(cn, tx, runGuid, selection, context.CancellationToken).ConfigureAwait(false);
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
                        request.Notes,
                        SelectedCount = selections.Count(x => x.IsSelected),
                        DeployableCount = selections.Count,
                        ExplicitSelectionCount = selections.Count
                    }),
                    context.CancellationToken).ConfigureAwait(false);

                await tx.CommitAsync(context.CancellationToken).ConfigureAwait(false);
            }
            catch
            {
                await tx.RollbackAsync(context.CancellationToken).ConfigureAwait(false);
                throw;
            }

            var counts = await ReadSchemaSelectionCountsAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false);
            return new SchemaMigrationSelectionResponse
            {
                Success = true,
                Message = $"Schema deployment selection saved. {counts.SelectedCount:N0} of {counts.DeployableCount:N0} deployable differences are selected. Revalidate and accept the updated plan before deployment.",
                SelectedCount = counts.SelectedCount,
                DeployableCount = counts.DeployableCount,
                ExplicitSelectionCount = counts.ExplicitSelectionCount
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Schema selection save SQL failed: {ex.Message}"));
        }
    }

    public override async Task<SchemaMigrationDeploymentPlanResponse> SchemaMigrationDeploymentPlan(
        SchemaMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        await using var cn = await OpenSchemaTargetSqlAsync(request.TargetServerName, request.TargetDatabaseName, context.CancellationToken).ConfigureAwait(false);
        var counts = await ReadSchemaSelectionCountsAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false);
        var rows = await ReadSchemaDeploymentPlanRowsAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false);

        var response = new SchemaMigrationDeploymentPlanResponse
        {
            SelectedCount = counts.SelectedCount,
            DeployableCount = counts.DeployableCount,
            HasExplicitSelection = counts.ExplicitSelectionCount > 0
        };
        response.Rows.AddRange(rows);
        return response;
    }

    public override async Task<SchemaMigrationOperationResponse> SchemaMigrationReviewSet(
        SchemaMigrationReviewRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenSchemaTargetSqlAsync(request.TargetServerName, request.TargetDatabaseName, context.CancellationToken).ConfigureAwait(false);
            var run = await ReadSchemaRunSummaryAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false);
            var isInitialAcceptance = run.RunStatus.Equals(SchemaMigrationValidated, StringComparison.OrdinalIgnoreCase);
            var isAcceptanceUpdate = run.IsReviewed
                && run.RunStatus.Equals(SchemaMigrationReviewed, StringComparison.OrdinalIgnoreCase);
            var reviewedByNote = (request.ReviewedByNote ?? string.Empty).Trim();

            if (!isInitialAcceptance && !isAcceptanceUpdate)
            {
                return new SchemaMigrationOperationResponse
                {
                    Success = false,
                    Message = "Schema acceptance can only be recorded after validation or updated while the unchanged plan remains in Reviewed status."
                };
            }

            if (isAcceptanceUpdate && string.IsNullOrWhiteSpace(reviewedByNote))
            {
                return new SchemaMigrationOperationResponse
                {
                    Success = false,
                    Message = "Enter an additional acceptance note before updating an already accepted schema run."
                };
            }

            var validation = await ReadSchemaValidationResponseAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false);
            if (validation.FailCount > 0)
            {
                return new SchemaMigrationOperationResponse
                {
                    Success = false,
                    Message = "Schema review cannot be completed while validation failures exist."
                };
            }

            await using var tx = (SqlTransaction)await cn.BeginTransactionAsync(context.CancellationToken).ConfigureAwait(false);
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
                    cmd.Parameters.Add(new SqlParameter("@ReviewedByNote", SqlDbType.NVarChar, 2000) { Value = reviewedByNote });
                    await cmd.ExecuteNonQueryAsync(context.CancellationToken).ConfigureAwait(false);
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
                    context.CancellationToken).ConfigureAwait(false);

                await tx.CommitAsync(context.CancellationToken).ConfigureAwait(false);
            }
            catch
            {
                await tx.RollbackAsync(context.CancellationToken).ConfigureAwait(false);
                throw;
            }

            return new SchemaMigrationOperationResponse
            {
                Success = true,
                Message = isAcceptanceUpdate
                    ? "Schema deployment acceptance note updated. The accepted plan is unchanged and remains ready for the controlled runner or worker."
                    : "Schema review completed and accepted for deployment. Deployment must still be performed through the approved source-controlled schema deployment process."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Schema review SQL failed: {ex.Message}"));
        }
    }

    public override async Task<SchemaMigrationOperationResponse> SchemaMigrationDeploymentOutcome(
        SchemaMigrationDeploymentOutcomeRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        var outcome = string.IsNullOrWhiteSpace(request.DeploymentOutcome) ? "Recorded" : request.DeploymentOutcome.Trim();

        try
        {
            await using var cn = await OpenSchemaTargetSqlAsync(request.TargetServerName, request.TargetDatabaseName, context.CancellationToken).ConfigureAwait(false);
            var run = await ReadSchemaRunSummaryAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false);
            var validation = await ReadSchemaValidationResponseAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false);

            if (!run.IsReviewed)
            {
                return new SchemaMigrationOperationResponse
                {
                    Success = false,
                    Message = "Deployment outcome cannot be recorded until the schema run is reviewed."
                };
            }

            if (validation.FailCount > 0)
            {
                return new SchemaMigrationOperationResponse
                {
                    Success = false,
                    Message = "Deployment outcome cannot be recorded while validation failures exist."
                };
            }

            await using var tx = (SqlTransaction)await cn.BeginTransactionAsync(context.CancellationToken).ConfigureAwait(false);
            try
            {
                await using (var cmd = new SqlCommand(@"
UPDATE SMigration.Schema_Run
SET
    RunStatus = @RunStatus,
    AppliedOnUtc = CASE WHEN @DeploymentOutcome IN (N'Succeeded', N'Applied', N'Deployed') THEN SYSUTCDATETIME() ELSE AppliedOnUtc END,
    DeploymentReference = @DeploymentReference,
    Notes = CASE WHEN LEN(@Notes) > 0 THEN CONCAT(Notes, CHAR(10), @Notes) ELSE Notes END
WHERE Guid = @RunGuid
  AND RowStatus <> 0
  AND RowStatus <> 254;", cn, tx)
                {
                    CommandType = CommandType.Text,
                    CommandTimeout = 300
                })
                {
                    cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
                    cmd.Parameters.Add(new SqlParameter("@RunStatus", SqlDbType.NVarChar, 30) { Value = SchemaMigrationDeploymentRecorded });
                    cmd.Parameters.Add(new SqlParameter("@DeploymentOutcome", SqlDbType.NVarChar, 30) { Value = outcome });
                    cmd.Parameters.Add(new SqlParameter("@DeploymentReference", SqlDbType.NVarChar, 100) { Value = request.DeploymentReference ?? string.Empty });
                    cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 2000) { Value = request.Notes ?? string.Empty });
                    await cmd.ExecuteNonQueryAsync(context.CancellationToken).ConfigureAwait(false);
                }

                await AddSchemaExecutionLogAsync(
                    cn,
                    tx,
                    runGuid,
                    "DeploymentOutcome",
                    outcome,
                    "Schema deployment outcome recorded for audit only. No schema or maintenance SQL was executed by the UI workbench.",
                    JsonSerializer.Serialize(new
                    {
                        request.DeploymentOutcome,
                        request.DeploymentReference,
                        request.Notes
                    }),
                    context.CancellationToken).ConfigureAwait(false);

                await tx.CommitAsync(context.CancellationToken).ConfigureAwait(false);
            }
            catch
            {
                await tx.RollbackAsync(context.CancellationToken).ConfigureAwait(false);
                throw;
            }

            return new SchemaMigrationOperationResponse
            {
                Success = true,
                Message = "Deployment outcome recorded for audit only. No schema or maintenance SQL was executed by the workbench; the controlled runner or external deployment process remains responsible for pre/post deployment maintenance."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Schema deployment audit SQL failed: {ex.Message}"));
        }
    }

    private enum SchemaMaintenanceProcedure
    {
        PreDeployment,
        PostDeployment
    }

    private static bool IsDevelopmentSchemaSource(string sourceEnvironment, string sourceDatabaseName)
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

    private static bool AreSameSqlDatabase(SqlConnection sourceConnection, SqlConnection targetConnection) =>
        sourceConnection.DataSource.Trim().Equals(targetConnection.DataSource.Trim(), StringComparison.OrdinalIgnoreCase)
        && sourceConnection.Database.Trim().Equals(targetConnection.Database.Trim(), StringComparison.OrdinalIgnoreCase);

    private static async Task ExecuteSchemaMaintenanceProcedureAsync(
        SqlConnection connection,
        SchemaMaintenanceProcedure procedure,
        CancellationToken cancellationToken)
    {
        var (objectName, executionSql) = procedure switch
        {
            SchemaMaintenanceProcedure.PreDeployment =>
                ("[SCore].[PreDeploymentScript]", "EXEC [SCore].[PreDeploymentScript];"),
            SchemaMaintenanceProcedure.PostDeployment =>
                ("[SCore].[PostDeploymentScript]", "EXEC [SCore].[PostDeploymentScript];"),
            _ => throw new ArgumentOutOfRangeException(nameof(procedure), procedure, "Unsupported schema maintenance procedure.")
        };

        await using var command = new SqlCommand($@"
IF OBJECT_ID(N'{objectName}', N'P') IS NULL
BEGIN
    THROW 60380, N'Required schema maintenance procedure {objectName} is not installed in the selected database.', 1;
END;

{executionSql}", connection)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 1800
        };

        await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    private static async Task<List<string>> RestoreSchemaComparePreparationAfterFailureAsync(
        SqlConnection sourceConnection,
        SqlConnection targetConnection,
        bool sourcePreDeploymentAttempted,
        bool targetPreDeploymentAttempted,
        bool sourceIsDevelopment,
        bool sourceAndTargetAreSameDatabase,
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
                    cancellationToken).ConfigureAwait(false);
            }
            catch (Exception recoveryException)
            {
                errors.Add($"Source recovery failed: {recoveryException.Message}");
            }
        }

        return errors;
    }

    private async Task<SqlConnection> OpenSchemaTargetSqlAsync(string targetServerName, string targetDatabaseName, CancellationToken cancellationToken)
    {
        await using var templateConnection = await OpenSqlAsync(cancellationToken).ConfigureAwait(false);
        return await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            targetServerName,
            targetDatabaseName,
            cancellationToken).ConfigureAwait(false);
    }

    private static async Task<List<SchemaObjectSnapshot>> ReadSchemaSnapshotAsync(SqlConnection cn, CancellationToken cancellationToken)
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
            result.Add(new SchemaObjectSnapshot(
                objectType,
                schemaName,
                objectName,
                parentObjectName,
                definition,
                ComputeSchemaHash(normalized)));
        }
    }

    private static List<SchemaComparisonDraft> BuildSchemaComparisonRows(
        IEnumerable<SchemaObjectSnapshot> sourceObjects,
        IEnumerable<SchemaObjectSnapshot> targetObjects)
    {
        static Dictionary<string, SchemaObjectSnapshot> BuildLookup(IEnumerable<SchemaObjectSnapshot> rows) =>
            rows.GroupBy(x => x.Key, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(x => x.Key, x => x.First(), StringComparer.OrdinalIgnoreCase);

        var source = BuildLookup(sourceObjects);
        var target = BuildLookup(targetObjects);
        var keys = source.Keys.Concat(target.Keys).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x, StringComparer.OrdinalIgnoreCase);
        var rows = new List<SchemaComparisonDraft>();

        foreach (var key in keys)
        {
            source.TryGetValue(key, out var sourceRow);
            target.TryGetValue(key, out var targetRow);
            var selected = sourceRow ?? targetRow;
            if (selected is null)
            {
                continue;
            }

            var differenceType = sourceRow is null
                ? "MissingInSource"
                : targetRow is null
                    ? "MissingInTarget"
                    : sourceRow.Hash.Equals(targetRow.Hash, StringComparison.OrdinalIgnoreCase)
                        ? "Equal"
                        : "Different";

            var objectType = selected.ObjectType;
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
                IsDeployable = differenceType is "MissingInTarget" or "Different",
                IsDestructiveRisk = isDestructiveRisk,
                Notes = BuildSchemaComparisonNote(differenceType, objectType, isDestructiveRisk)
            });
        }

        return rows;
    }

    private static List<SchemaValidationDraft> BuildSchemaValidationIssues(IEnumerable<SchemaMigrationObjectComparisonRow> rows)
    {
        var issues = new List<SchemaValidationDraft>();
        var rowList = rows.ToList();

        if (rowList.Count == 0)
        {
            issues.Add(new SchemaValidationDraft
            {
                Severity = "Fail",
                IssueCode = "NO_COMPARISON_ROWS",
                IssueMessage = "No schema comparison rows exist. Run Stage & Compare before validation.",
                DetailsJson = "{}"
            });
            return issues;
        }

        foreach (var row in rowList.Where(x => !x.DifferenceType.Equals("Equal", StringComparison.OrdinalIgnoreCase)))
        {
            var unsupportedStandaloneType = row.ObjectType is "Constraint" or "Index";
            var requiresDedicatedMigration = row.DifferenceType.Equals("Different", StringComparison.OrdinalIgnoreCase)
                && row.ObjectType is "Table" or "TableType" or "Sequence";
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

            // These conditions are deterministic runner blockers, not advisory warnings. An accepted
            // plan containing them cannot complete without narrowing the persisted selection or adding
            // a reviewed source-controlled migration/mapping.
            var severity = row.DifferenceType switch
            {
                "MissingInSource" => "Warn",
                _ when unsupportedStandaloneType || requiresDedicatedMigration || unsupportedObjectType => "Fail",
                "Different" => "Info",
                "MissingInTarget" => "Info",
                _ => "Info"
            };

            var code = row.DifferenceType switch
            {
                "MissingInSource" => "TARGET_ONLY_OBJECT",
                _ when unsupportedStandaloneType => "MANUAL_RUNNER_UNSUPPORTED_OBJECT",
                _ when requiresDedicatedMigration => "MANUAL_RUNNER_REQUIRES_MIGRATION_SCRIPT",
                _ when unsupportedObjectType => "MANUAL_RUNNER_UNMAPPED_OBJECT_TYPE",
                "MissingInTarget" => "SOURCE_ONLY_OBJECT",
                "Different" => "OBJECT_DEFINITION_DIFFERS",
                _ => "SCHEMA_DIFFERENCE"
            };

            var message = row.DifferenceType switch
            {
                "MissingInSource" => "Object exists in target but not source. Treat as target drift or destructive change risk; resolve through source-controlled SQL before promotion.",
                _ when unsupportedStandaloneType => $"The controlled runner does not deploy standalone {row.ObjectType} rows. If this row is mechanically handled by a selected dedicated parent-object migration, remove the standalone row from the saved selection. Otherwise add an explicit source-controlled idempotent migration for this {row.ObjectType}; captured database DDL will not be executed.",
                _ when requiresDedicatedMigration => $"Existing {row.ObjectType} definition differs. The controlled runner will not recreate it; provide a dedicated source-controlled, non-destructive migration script.",
                _ when unsupportedObjectType => $"The controlled runner has no source-controlled SQL mapping for object type {row.ObjectType}. Narrow the saved selection or add an approved runner mapping and idempotent schema artefact.",
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

    private static string BuildSchemaComparisonNote(string differenceType, string objectType, bool isDestructiveRisk) =>
        differenceType switch
        {
            "Equal" => "No schema definition difference detected.",
            "MissingInTarget" => "Source-controlled deployment should create this target object idempotently.",
            "MissingInSource" => "Target-only object. Investigate drift; do not remove without approval.",
            "Different" when isDestructiveRisk => $"{objectType} differs and may require data-preserving migration planning.",
            "Different" => "Definition differs. Review source-controlled SQL and deployment ordering.",
            _ => "Schema difference requires review."
        };

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

    private static async Task DeactivateSchemaRowsAsync(
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

    private static async Task InvalidateSchemaValidationAndReviewAsync(
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

    private static async Task UpdateSchemaRunStatusAsync(
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

    private static async Task<IReadOnlyList<string>> ReadSchemaMigrationBootstrapMissingObjectsAsync(
        SqlConnection cn,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
SELECT
    required.RequiredObject
FROM
(
    VALUES
        (10, N'Schema [SMigration]', CONVERT(BIT, CASE WHEN SCHEMA_ID(N'SMigration') IS NULL THEN 0 ELSE 1 END)),
        (20, N'Table [SMigration].[Schema_Run]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_Run]', N'U') IS NULL THEN 0 ELSE 1 END)),
        (30, N'Table [SMigration].[Schema_ObjectComparisons]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_ObjectComparisons]', N'U') IS NULL THEN 0 ELSE 1 END)),
        (40, N'Table [SMigration].[Schema_ValidationIssues]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_ValidationIssues]', N'U') IS NULL THEN 0 ELSE 1 END)),
        (50, N'Table [SMigration].[Schema_ExecutionLog]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_ExecutionLog]', N'U') IS NULL THEN 0 ELSE 1 END)),
        (60, N'Table [SMigration].[Schema_RunSelections]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[Schema_RunSelections]', N'U') IS NULL THEN 0 ELSE 1 END)),
        (70, N'Procedure [SMigration].[SchemaDataObject_Ensure]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[SchemaDataObject_Ensure]', N'P') IS NULL THEN 0 ELSE 1 END)),
        (80, N'Procedure [SMigration].[SchemaDeploymentPlan_Get]', CONVERT(BIT, CASE WHEN OBJECT_ID(N'[SMigration].[SchemaDeploymentPlan_Get]', N'P') IS NULL THEN 0 ELSE 1 END))
) AS required
(
    SortOrder,
    RequiredObject,
    IsPresent
)
WHERE required.IsPresent = 0
ORDER BY required.SortOrder;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        var missingObjects = new List<string>();
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            missingObjects.Add(reader.GetString(0));
        }

        return missingObjects;
    }

    private static async Task EnsureSchemaDataObjectAsync(
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

    private static async Task AddSchemaExecutionLogAsync(
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

    private static async Task<SchemaMigrationRunSummary> ReadSchemaRunSummaryAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
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
    r.SummaryJson
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
            return MapSchemaRunSummary(reader);
        }

        throw new RpcException(new Status(StatusCode.NotFound, "Schema migration run was not found."));
    }

    private static async Task<SchemaMigrationDashboardMessage> ReadSchemaDashboardAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        var dashboard = new SchemaMigrationDashboardMessage
        {
            Run = await ReadSchemaRunSummaryAsync(cn, runGuid, cancellationToken).ConfigureAwait(false)
        };

        await using (var cmd = new SqlCommand(@"
SELECT
    c.DifferenceType,
    COUNT_BIG(1) AS [RowCount]
FROM SMigration.Schema_ObjectComparisons AS c
WHERE c.RunGuid = @RunGuid
  AND c.RowStatus <> 0
  AND c.RowStatus <> 254
GROUP BY c.DifferenceType;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        })
        {
            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                var differenceType = reader.GetString(0);
                var count = Convert.ToInt32(reader.GetInt64(1));
                switch (differenceType)
                {
                    case "Equal": dashboard.EqualCount = count; break;
                    case "MissingInTarget": dashboard.MissingInTargetCount = count; break;
                    case "MissingInSource": dashboard.MissingInSourceCount = count; break;
                    case "Different": dashboard.DifferentCount = count; break;
                }
            }
        }

        await using (var cmd = new SqlCommand(@"
SELECT
    c.ObjectType,
    c.DifferenceType,
    COUNT_BIG(1) AS [RowCount]
FROM SMigration.Schema_ObjectComparisons AS c
WHERE c.RunGuid = @RunGuid
  AND c.RowStatus <> 0
  AND c.RowStatus <> 254
GROUP BY c.ObjectType,
         c.DifferenceType
ORDER BY c.ObjectType,
         c.DifferenceType;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        })
        {
            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                dashboard.ObjectTypeCounts.Add(new SchemaMigrationObjectTypeCount
                {
                    ObjectType = reader.GetString(0),
                    DifferenceType = reader.GetString(1),
                    Count = Convert.ToInt32(reader.GetInt64(2))
                });
            }
        }

        var validation = await ReadSchemaValidationResponseAsync(cn, runGuid, cancellationToken).ConfigureAwait(false);
        dashboard.FailCount = validation.FailCount;
        dashboard.WarnCount = validation.WarnCount;
        dashboard.InfoCount = validation.InfoCount;
        dashboard.ValidationIssues.AddRange(validation.ValidationIssues);
        dashboard.ExecutionLog.AddRange(await ReadSchemaExecutionLogAsync(cn, runGuid, cancellationToken).ConfigureAwait(false));

        return dashboard;
    }

    private static async Task<SchemaMigrationValidateResponse> ReadSchemaValidationResponseAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        var response = new SchemaMigrationValidateResponse();
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
            var item = new SchemaMigrationValidationIssue
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

    private static async Task<List<SchemaMigrationExecutionLogItem>> ReadSchemaExecutionLogAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        var result = new List<SchemaMigrationExecutionLogItem>();
        await using var cmd = new SqlCommand(@"
SELECT TOP (100)
    l.StepName,
    l.StepStatus,
    l.Message,
    l.DetailsJson,
    l.CreatedOnUtc
FROM SMigration.Schema_ExecutionLog AS l
WHERE l.RunGuid = @RunGuid
  AND l.RowStatus <> 0
  AND l.RowStatus <> 254
ORDER BY l.ID DESC;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            result.Add(new SchemaMigrationExecutionLogItem
            {
                StepName = reader.GetString(0),
                StepStatus = reader.GetString(1),
                Message = reader.GetString(2),
                DetailsJson = reader.GetString(3),
                CreatedOnUtc = FormatDateTime(reader, 4)
            });
        }

        return result;
    }

    private static async Task<List<SchemaMigrationObjectComparisonRow>> ReadSchemaComparisonRowsAsync(
        SqlConnection cn,
        Guid runGuid,
        string objectType,
        string differenceType,
        string searchText,
        bool includeDefinitions,
        Guid? comparisonGuid,
        CancellationToken cancellationToken)
    {
        var rows = new List<SchemaMigrationObjectComparisonRow>();
        await using var cmd = new SqlCommand(@"
DECLARE @HasExplicitSelection BIT =
(
    SELECT
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM SMigration.Schema_RunSelections AS rs
                WHERE rs.RunGuid = @RunGuid
                  AND rs.RowStatus <> 0
                  AND rs.RowStatus <> 254
            ) THEN CONVERT(BIT, 1)
            ELSE CONVERT(BIT, 0)
        END
);

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
    CASE
        WHEN c.IsDeployable = 0 THEN CONVERT(BIT, 0)
        WHEN @HasExplicitSelection = 0 THEN CONVERT(BIT, 1)
        ELSE ISNULL(sel.IsSelected, CONVERT(BIT, 0))
    END AS IsSelected,
    CASE WHEN sel.Guid IS NULL THEN CONVERT(BIT, 0) ELSE CONVERT(BIT, 1) END AS HasExplicitSelection
FROM SMigration.Schema_ObjectComparisons AS c
OUTER APPLY
(
    SELECT TOP (1)
        rs.Guid,
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
            rows.Add(new SchemaMigrationObjectComparisonRow
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
                HasExplicitSelection = reader.GetBoolean(14)
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
    SelectedOnUtc
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
    SYSUTCDATETIME()
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
        await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    private static async Task<SchemaSelectionCounts> ReadSchemaSelectionCountsAsync(
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
);

SELECT
    @DeployableCount AS DeployableCount,
    CASE
        WHEN @ExplicitSelectionCount = 0 THEN @DeployableCount
        ELSE
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
              AND ISNULL(sel.IsSelected, CONVERT(BIT, 0)) = 1
        )
    END AS SelectedCount,
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

    private static async Task<List<SchemaMigrationObjectComparisonRow>> ReadSchemaDeploymentPlanRowsAsync(
        SqlConnection cn,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        var rows = new List<SchemaMigrationObjectComparisonRow>();
        await using var cmd = new SqlCommand(@"
DECLARE @HasExplicitSelection BIT =
(
    SELECT
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM SMigration.Schema_RunSelections AS rs
                WHERE rs.RunGuid = @RunGuid
                  AND rs.RowStatus <> 0
                  AND rs.RowStatus <> 254
            ) THEN CONVERT(BIT, 1)
            ELSE CONVERT(BIT, 0)
        END
);

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
    CONVERT(NVARCHAR(MAX), N'') AS SourceDefinition,
    CONVERT(NVARCHAR(MAX), N'') AS TargetDefinition,
    c.Notes,
    CONVERT(BIT, 1) AS IsSelected,
    CASE WHEN sel.Guid IS NULL THEN CONVERT(BIT, 0) ELSE CONVERT(BIT, 1) END AS HasExplicitSelection
FROM SMigration.Schema_ObjectComparisons AS c
OUTER APPLY
(
    SELECT TOP (1)
        rs.Guid,
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
  AND (@HasExplicitSelection = 0 OR ISNULL(sel.IsSelected, CONVERT(BIT, 0)) = 1)
ORDER BY
    CASE c.ObjectType
        WHEN N'Schema' THEN 10
        WHEN N'TableType' THEN 20
        WHEN N'Table' THEN 30
        WHEN N'Sequence' THEN 40
        WHEN N'Constraint' THEN 50
        WHEN N'Index' THEN 60
        WHEN N'View' THEN 70
        WHEN N'Function' THEN 80
        WHEN N'StoredProcedure' THEN 90
        WHEN N'Trigger' THEN 100
        ELSE 900
    END,
    c.SchemaName,
    c.ObjectName;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            rows.Add(new SchemaMigrationObjectComparisonRow
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
                HasExplicitSelection = reader.GetBoolean(14)
            });
        }

        return rows;
    }

    private static string BuildSchemaSelectionKey(SchemaMigrationSelectionItem item) =>
        string.Join("|", item.ObjectType, item.SchemaName, item.ObjectName, item.ParentObjectName);

    private static string BuildSchemaSelectionKey(SchemaMigrationObjectComparisonRow row) =>
        string.Join("|", row.ObjectType, row.SchemaName, row.ObjectName, row.ParentObjectName);

    private static SchemaMigrationRunSummary MapSchemaRunSummary(SqlDataReader reader)
    {
        return new SchemaMigrationRunSummary
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
            SummaryJson = reader.GetString(17)
        };
    }

    private static string FormatDateTime(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? string.Empty : reader.GetDateTime(ordinal).ToString("yyyy-MM-dd HH:mm:ss");

    private static string NormalizeSchemaDefinition(string definition)
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

        return builder.ToString();
    }

    private static string ComputeSchemaHash(string value)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(value ?? string.Empty));
        return Convert.ToHexString(bytes);
    }

    private static string EscapeLikeValue(string value) =>
        value.Replace("[", "[[]", StringComparison.Ordinal)
             .Replace("%", "[%]", StringComparison.Ordinal)
             .Replace("_", "[_]", StringComparison.Ordinal);

    private sealed record SchemaObjectSnapshot(
        string ObjectType,
        string SchemaName,
        string ObjectName,
        string ParentObjectName,
        string Definition,
        string Hash)
    {
        public string Key => $"{ObjectType}|{SchemaName}|{ObjectName}|{ParentObjectName}";
    }

    private sealed class SchemaComparisonDraft
    {
        public Guid ComparisonGuid { get; init; }
        public string ObjectType { get; init; } = string.Empty;
        public string SchemaName { get; init; } = string.Empty;
        public string ObjectName { get; init; } = string.Empty;
        public string ParentObjectName { get; init; } = string.Empty;
        public string DifferenceType { get; init; } = string.Empty;
        public string SourceHash { get; init; } = string.Empty;
        public string TargetHash { get; init; } = string.Empty;
        public string SourceDefinition { get; init; } = string.Empty;
        public string TargetDefinition { get; init; } = string.Empty;
        public bool IsDeployable { get; init; }
        public bool IsDestructiveRisk { get; init; }
        public string Notes { get; init; } = string.Empty;
    }

    private sealed record SchemaSelectionCounts(int DeployableCount, int SelectedCount, int ExplicitSelectionCount);

    private sealed class SchemaSelectionDraft
    {
        public Guid ComparisonGuid { get; init; }
        public string ObjectType { get; init; } = string.Empty;
        public string SchemaName { get; init; } = string.Empty;
        public string ObjectName { get; init; } = string.Empty;
        public string ParentObjectName { get; init; } = string.Empty;
        public bool IsSelected { get; init; }
        public string SelectionNote { get; init; } = string.Empty;
    }

    private sealed class SchemaValidationDraft
    {
        public Guid ComparisonGuid { get; init; }
        public string Severity { get; init; } = string.Empty;
        public string IssueCode { get; init; } = string.Empty;
        public string IssueMessage { get; init; } = string.Empty;
        public string ObjectType { get; init; } = string.Empty;
        public string SchemaName { get; init; } = string.Empty;
        public string ObjectName { get; init; } = string.Empty;
        public string DetailsJson { get; init; } = "{}";
    }

    private static class SchemaSnapshotSql
    {
        public const string Schemas = @"
SELECT
    CONVERT(NVARCHAR(50), N'Schema') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), s.name) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), s.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), N'') COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'CREATE SCHEMA ') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), QUOTENAME(s.name)) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.schemas AS s
WHERE s.name NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY s.name;";

        public const string Tables = @"
SELECT
    CONVERT(NVARCHAR(50), N'Table') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), sch.name) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), t.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), N'') COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONVERT(NVARCHAR(MAX), ISNULL
    (
        (
            SELECT
                c.column_id AS ColumnId,
                c.name AS ColumnName,
                ty.name AS DataTypeName,
                c.max_length AS MaxLength,
                c.precision AS PrecisionValue,
                c.scale AS ScaleValue,
                c.is_nullable AS IsNullable,
                c.is_identity AS IsIdentity,
                c.is_computed AS IsComputed,
                cc.definition AS ComputedDefinition,
                dc.definition AS DefaultDefinition
            FROM sys.columns AS c
            INNER JOIN sys.types AS ty
                ON ty.user_type_id = c.user_type_id
            LEFT JOIN sys.computed_columns AS cc
                ON cc.object_id = c.object_id
               AND cc.column_id = c.column_id
            LEFT JOIN sys.default_constraints AS dc
                ON dc.parent_object_id = c.object_id
               AND dc.parent_column_id = c.column_id
            WHERE c.object_id = t.object_id
            ORDER BY c.column_id
            FOR JSON PATH
        ),
        N'[]'
    )) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.tables AS t
INNER JOIN sys.schemas AS sch
    ON sch.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
  AND sch.name NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY sch.name,
         t.name;";

        public const string TableTypes = @"
SELECT
    CONVERT(NVARCHAR(50), N'TableType') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), sch.name) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), tt.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), N'') COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONVERT(NVARCHAR(MAX), ISNULL
    (
        (
            SELECT
                c.column_id AS ColumnId,
                c.name AS ColumnName,
                ty.name AS DataTypeName,
                c.max_length AS MaxLength,
                c.precision AS PrecisionValue,
                c.scale AS ScaleValue,
                c.is_nullable AS IsNullable
            FROM sys.columns AS c
            INNER JOIN sys.types AS ty
                ON ty.user_type_id = c.user_type_id
            WHERE c.object_id = tt.type_table_object_id
            ORDER BY c.column_id
            FOR JSON PATH
        ),
        N'[]'
    )) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.table_types AS tt
INNER JOIN sys.schemas AS sch
    ON sch.schema_id = tt.schema_id
WHERE sch.name NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY sch.name,
         tt.name;";

        public const string Modules = @"
SELECT
    CASE o.type
        WHEN N'V' THEN CONVERT(NVARCHAR(50), N'View') COLLATE DATABASE_DEFAULT
        WHEN N'P' THEN CONVERT(NVARCHAR(50), N'StoredProcedure') COLLATE DATABASE_DEFAULT
        WHEN N'FN' THEN CONVERT(NVARCHAR(50), N'Function') COLLATE DATABASE_DEFAULT
        WHEN N'IF' THEN CONVERT(NVARCHAR(50), N'Function') COLLATE DATABASE_DEFAULT
        WHEN N'TF' THEN CONVERT(NVARCHAR(50), N'Function') COLLATE DATABASE_DEFAULT
        WHEN N'FS' THEN CONVERT(NVARCHAR(50), N'Function') COLLATE DATABASE_DEFAULT
        WHEN N'FT' THEN CONVERT(NVARCHAR(50), N'Function') COLLATE DATABASE_DEFAULT
        WHEN N'TR' THEN CONVERT(NVARCHAR(50), N'Trigger') COLLATE DATABASE_DEFAULT
        ELSE CONVERT(NVARCHAR(50), o.type_desc) COLLATE DATABASE_DEFAULT
    END AS ObjectType,
    CONVERT(NVARCHAR(256), sch.name) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), o.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CASE
        WHEN o.parent_object_id > 0 THEN CONCAT
        (
            CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(o.parent_object_id)) COLLATE DATABASE_DEFAULT,
            CONVERT(NVARCHAR(1), N'.') COLLATE DATABASE_DEFAULT,
            CONVERT(NVARCHAR(256), OBJECT_NAME(o.parent_object_id)) COLLATE DATABASE_DEFAULT
        ) COLLATE DATABASE_DEFAULT
        ELSE CONVERT(NVARCHAR(256), N'') COLLATE DATABASE_DEFAULT
    END AS ParentObjectName,
    CONVERT(NVARCHAR(MAX), ISNULL(m.definition, N'')) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.objects AS o
INNER JOIN sys.schemas AS sch
    ON sch.schema_id = o.schema_id
INNER JOIN sys.sql_modules AS m
    ON m.object_id = o.object_id
WHERE o.is_ms_shipped = 0
  AND o.type IN (N'V', N'P', N'FN', N'IF', N'TF', N'FS', N'FT', N'TR')
  AND sch.name NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY ObjectType,
         sch.name,
         o.name;";

        public const string Sequences = @"
SELECT
    CONVERT(NVARCHAR(50), N'Sequence') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), sch.name) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), seq.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), N'') COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'TYPE=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), TYPE_NAME(seq.system_type_id)) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';START=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.start_value) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';INCREMENT=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.increment) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';MIN=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.minimum_value) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';MAX=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.maximum_value) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';CYCLE=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.is_cycling) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';CACHE=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.cache_size) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.sequences AS seq
INNER JOIN sys.schemas AS sch
    ON sch.schema_id = seq.schema_id
WHERE sch.name NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY sch.name,
         seq.name;";

        public const string KeyConstraints = @"
SELECT
    CONVERT(NVARCHAR(50), N'Constraint') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(k.parent_object_id)) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), k.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), OBJECT_NAME(k.parent_object_id)) COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), k.type_desc) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), ISNULL((
            SELECT
                c.name COLLATE DATABASE_DEFAULT AS ColumnName,
                ic.key_ordinal AS KeyOrdinal,
                ic.is_descending_key AS IsDescending
            FROM sys.index_columns AS ic
            INNER JOIN sys.columns AS c
                ON c.object_id = ic.object_id
               AND c.column_id = ic.column_id
            WHERE ic.object_id = k.parent_object_id
              AND ic.index_id = k.unique_index_id
            ORDER BY ic.key_ordinal
            FOR JSON PATH
        ), N'[]')) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.key_constraints AS k
WHERE OBJECT_SCHEMA_NAME(k.parent_object_id) NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY SchemaName,
         ParentObjectName,
         ObjectName;";

        public const string ForeignKeyConstraints = @"
SELECT
    CONVERT(NVARCHAR(50), N'Constraint') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(fk.parent_object_id)) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), fk.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), OBJECT_NAME(fk.parent_object_id)) COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'FOREIGN_KEY;') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N'DELETE=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), fk.delete_referential_action_desc) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';UPDATE=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), fk.update_referential_action_desc) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';REF=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), OBJECT_SCHEMA_NAME(fk.referenced_object_id)) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N'.') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), OBJECT_NAME(fk.referenced_object_id)) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), ISNULL((
            SELECT
                pc.name COLLATE DATABASE_DEFAULT AS ParentColumn,
                rc.name COLLATE DATABASE_DEFAULT AS ReferencedColumn,
                fkc.constraint_column_id AS ColumnOrder
            FROM sys.foreign_key_columns AS fkc
            INNER JOIN sys.columns AS pc
                ON pc.object_id = fkc.parent_object_id
               AND pc.column_id = fkc.parent_column_id
            INNER JOIN sys.columns AS rc
                ON rc.object_id = fkc.referenced_object_id
               AND rc.column_id = fkc.referenced_column_id
            WHERE fkc.constraint_object_id = fk.object_id
            ORDER BY fkc.constraint_column_id
            FOR JSON PATH
        ), N'[]')) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.foreign_keys AS fk
WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY SchemaName,
         ParentObjectName,
         ObjectName;";

        public const string CheckConstraints = @"
SELECT
    CONVERT(NVARCHAR(50), N'Constraint') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(cc.parent_object_id)) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), cc.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), OBJECT_NAME(cc.parent_object_id)) COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'CHECK;') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), ISNULL(cc.definition, N'')) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.check_constraints AS cc
WHERE OBJECT_SCHEMA_NAME(cc.parent_object_id) NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY SchemaName,
         ParentObjectName,
         ObjectName;";

        public const string DefaultConstraints = @"
SELECT
    CONVERT(NVARCHAR(50), N'Constraint') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(dc.parent_object_id)) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), dc.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), OBJECT_NAME(dc.parent_object_id)) COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'DEFAULT;') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), COL_NAME(dc.parent_object_id, dc.parent_column_id)) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), ISNULL(dc.definition, N'')) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.default_constraints AS dc
WHERE OBJECT_SCHEMA_NAME(dc.parent_object_id) NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY SchemaName,
         ParentObjectName,
         ObjectName;";

        public const string Indexes = @"
SELECT
    CONVERT(NVARCHAR(50), N'Index') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(i.object_id)) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONCAT
    (
        CONVERT(NVARCHAR(256), OBJECT_NAME(i.object_id)) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(1), N'.') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(256), i.name) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), OBJECT_NAME(i.object_id)) COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), i.type_desc) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';UNIQUE=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), i.is_unique) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';FILTER=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), ISNULL(i.filter_definition, N'')) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';COLUMNS=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), ISNULL((
            SELECT
                c.name AS ColumnName,
                ic.key_ordinal AS KeyOrdinal,
                ic.is_included_column AS IsIncluded,
                ic.is_descending_key AS IsDescending
            FROM sys.index_columns AS ic
            INNER JOIN sys.columns AS c
                ON c.object_id = ic.object_id
               AND c.column_id = ic.column_id
            WHERE ic.object_id = i.object_id
              AND ic.index_id = i.index_id
            ORDER BY ic.key_ordinal,
                     ic.index_column_id
            FOR JSON PATH
        ), N'[]')) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.indexes AS i
INNER JOIN sys.objects AS o
    ON o.object_id = i.object_id
WHERE i.index_id > 0
  AND i.is_hypothetical = 0
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND o.is_ms_shipped = 0
  AND OBJECT_SCHEMA_NAME(i.object_id) NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY SchemaName,
         ParentObjectName,
         ObjectName;";
    }

}
