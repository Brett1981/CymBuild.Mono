using Concursus.API.Core;
using Concursus.EF.SchemaMigration;
using Grpc.Core;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Text.Json;
using static Concursus.EF.SchemaMigration.SchemaMigrationEngine;
using static Concursus.EF.SchemaMigration.SchemaMigrationRules;

namespace Concursus.API.Services;

// The Schema Migration workbench RPCs. Create/compare/select/validate/accept and every snapshot,
// normalise, hash, diff, validation and persistence helper live in Concursus.EF.SchemaMigration
// (SchemaMigrationEngine / SchemaMigrationRules) so the headless CLI runs the identical code; these
// methods keep their auth, request validation, gRPC status mapping and proto response shaping.
public partial class CoreService
{
    private SchemaMigrationEngine? _schemaMigrationEngine;

    private SchemaMigrationEngine SchemaEngine =>
        _schemaMigrationEngine ??= new SchemaMigrationEngine(ResolveSqlConnectionString(), _migrationBootstrapRepository);

    private static RpcException ToSchemaRpcException(SchemaMigrationException ex) =>
        new(new Status(
            ex.Kind switch
            {
                SchemaMigrationErrorKind.NotFound => StatusCode.NotFound,
                SchemaMigrationErrorKind.InvalidArgument => StatusCode.InvalidArgument,
                _ => StatusCode.FailedPrecondition
            },
            ex.Message));

    [Microsoft.AspNetCore.Authorization.Authorize(Roles = "User.ReadWrite,SysAdmin")]
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
            var run = await SchemaEngine.CreateRunAsync(
                new SchemaRunCreateOptions(
                    request.SourceEnvironment,
                    request.SourceServerName,
                    request.SourceDatabaseName,
                    request.TargetEnvironment,
                    request.TargetServerName,
                    request.TargetDatabaseName,
                    request.JiraReference,
                    request.ReleaseReference,
                    request.Notes),
                context.CancellationToken).ConfigureAwait(false);

            return new SchemaMigrationRunResponse
            {
                Run = ToSchemaRunSummary(run)
            };
        }
        catch (SchemaMigrationException ex)
        {
            throw ToSchemaRpcException(ex);
        }
        catch (Concursus.EF.MigrationBootstrapRepository.MigrationBootstrapException ex)
        {
            throw new RpcException(new Status(StatusCode.FailedPrecondition, ex.Message));
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

    [Microsoft.AspNetCore.Authorization.Authorize(Roles = "User.ReadWrite,SysAdmin")]
    public override async Task<SchemaMigrationRunsResponse> SchemaMigrationRuns(
        SchemaMigrationRunsRequest request,
        ServerCallContext context)
    {
        try
        {
            await _migrationBootstrapRepository.EnsureSchemaWorkbenchAsync(
                request.TargetServerName,
                request.TargetDatabaseName,
                string.Empty,
                context.CancellationToken).ConfigureAwait(false);
        }
        catch (Concursus.EF.MigrationBootstrapRepository.MigrationBootstrapException ex)
        {
            throw new RpcException(new Status(StatusCode.FailedPrecondition, ex.Message));
        }

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
    r.SummaryJson,
    r.SourceSyncedOnUtc,
    r.SourceSyncCommit
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
            response.Runs.Add(ToSchemaRunSummary(MapSchemaRunRecord(reader)));
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
            Run = ToSchemaRunSummary(await ReadSchemaRunSummaryAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false))
        };
    }

    public override async Task<SchemaMigrationDashboardResponse> SchemaMigrationCompare(
        SchemaMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await SchemaEngine.CompareAsync(
                request.TargetServerName,
                request.TargetDatabaseName,
                runGuid,
                enforceSourceSyncGate: true,
                context.CancellationToken).ConfigureAwait(false);

            await using var targetConnection = await OpenSchemaTargetSqlAsync(
                request.TargetServerName,
                request.TargetDatabaseName,
                context.CancellationToken).ConfigureAwait(false);
            return new SchemaMigrationDashboardResponse
            {
                Dashboard = await ReadSchemaDashboardAsync(targetConnection, runGuid, context.CancellationToken).ConfigureAwait(false)
            };
        }
        catch (SchemaMigrationException ex)
        {
            throw ToSchemaRpcException(ex);
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
            var validation = await SchemaEngine.ValidateAsync(
                request.TargetServerName,
                request.TargetDatabaseName,
                runGuid,
                context.CancellationToken).ConfigureAwait(false);
            return ToSchemaValidateResponse(validation);
        }
        catch (SchemaMigrationException ex)
        {
            throw ToSchemaRpcException(ex);
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
        var run = await ReadSchemaRunSummaryAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false);
        await EnsureSchemaExclusionInfrastructureAsync(
            "TARGET",
            run.TargetServerName,
            run.TargetDatabaseName,
            run.TargetEnvironment,
            context.CancellationToken).ConfigureAwait(false);
        return new SchemaMigrationDashboardResponse
        {
            Dashboard = await ReadSchemaDashboardAsync(cn, runGuid, context.CancellationToken).ConfigureAwait(false)
        };
    }

    public override async Task<SchemaMigrationExcludedObjectsResponse> SchemaMigrationExcludedObjects(
        SchemaMigrationExcludedObjectsRequest request,
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

            await EnsureSchemaExclusionInfrastructureAsync(
                "SOURCE",
                run.SourceServerName,
                run.SourceDatabaseName,
                run.SourceEnvironment,
                context.CancellationToken).ConfigureAwait(false);
            await EnsureSchemaExclusionInfrastructureAsync(
                "TARGET",
                run.TargetServerName,
                run.TargetDatabaseName,
                run.TargetEnvironment,
                context.CancellationToken).ConfigureAwait(false);

            var sourceRecords = await ReadSchemaExcludedObjectRecordsAsync(
                sourceConnection,
                request.IncludeInactive,
                context.CancellationToken).ConfigureAwait(false);
            var targetRecords = AreSameSqlDatabase(sourceConnection, targetConnection)
                ? sourceRecords
                : await ReadSchemaExcludedObjectRecordsAsync(
                    targetConnection,
                    includeInactive: true,
                    context.CancellationToken).ConfigureAwait(false);
            var targetByKey = targetRecords
                .GroupBy(x => x.StableObjectKey, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(x => x.Key, x => x.OrderByDescending(y => y.ID).First(), StringComparer.OrdinalIgnoreCase);

            var response = new SchemaMigrationExcludedObjectsResponse
            {
                ExcludedCount = sourceRecords.Count(x => x.IsActive),
                Message = "Schema exclusions are source-authoritative and are synchronized to the selected target during comparison."
            };

            foreach (var record in sourceRecords)
            {
                targetByKey.TryGetValue(record.StableObjectKey, out var targetRecord);
                response.Records.Add(MapSchemaExcludedObject(record, targetRecord));
            }

            return response;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Schema excluded objects SQL failed: {ex.Message}"));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new RpcException(new Status(StatusCode.Internal, $"Schema excluded objects failed: {ex.Message}"));
        }
    }

    public override async Task<SchemaMigrationExclusionResponse> SchemaMigrationExclusionUpsert(
        SchemaMigrationExclusionUpsertRequest request,
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

            await EnsureSchemaExclusionInfrastructureAsync(
                "SOURCE",
                run.SourceServerName,
                run.SourceDatabaseName,
                run.SourceEnvironment,
                context.CancellationToken).ConfigureAwait(false);
            await EnsureSchemaExclusionInfrastructureAsync(
                "TARGET",
                run.TargetServerName,
                run.TargetDatabaseName,
                run.TargetEnvironment,
                context.CancellationToken).ConfigureAwait(false);

            var objectIdentity = await ResolveSchemaExclusionObjectIdentityAsync(
                targetConnection,
                runGuid,
                request,
                context.CancellationToken).ConfigureAwait(false);
            var reason = (request.Reason ?? string.Empty).Trim();
            if (request.IsExcluded && string.IsNullOrWhiteSpace(reason))
            {
                throw new RpcException(new Status(StatusCode.InvalidArgument, "An exclusion reason is required."));
            }

            var actorUserId = await ReadSchemaCurrentUserIdAsync(targetConnection, context.CancellationToken).ConfigureAwait(false);
            var sourceRecords = await ReadSchemaExcludedObjectRecordsAsync(
                sourceConnection,
                includeInactive: true,
                context.CancellationToken).ConfigureAwait(false);
            var stableObjectKey = BuildSchemaStableObjectKey(
                objectIdentity.ObjectType,
                objectIdentity.SchemaName,
                objectIdentity.ObjectName,
                objectIdentity.ParentObjectName);
            var existingSourceRecord = sourceRecords.FirstOrDefault(x =>
                x.StableObjectKey.Equals(stableObjectKey, StringComparison.OrdinalIgnoreCase));
            var exclusionGuid = existingSourceRecord?.Guid ?? Guid.NewGuid();

            exclusionGuid = await ApplySchemaExcludedObjectAsync(
                sourceConnection,
                null,
                exclusionGuid,
                objectIdentity,
                reason,
                request.IsExcluded,
                sourceConnection.DataSource,
                sourceConnection.Database,
                actorUserId,
                runGuid,
                context.CancellationToken).ConfigureAwait(false);

            await using var targetTx = (SqlTransaction)await targetConnection.BeginTransactionAsync(context.CancellationToken).ConfigureAwait(false);
            try
            {
                if (!AreSameSqlDatabase(sourceConnection, targetConnection))
                {
                    await ApplySchemaExcludedObjectAsync(
                        targetConnection,
                        targetTx,
                        exclusionGuid,
                        objectIdentity,
                        reason,
                        request.IsExcluded,
                        sourceConnection.DataSource,
                        sourceConnection.Database,
                        actorUserId,
                        runGuid,
                        context.CancellationToken).ConfigureAwait(false);
                }

                await DeactivateSchemaSelectionForObjectAsync(
                    targetConnection,
                    targetTx,
                    runGuid,
                    objectIdentity,
                    context.CancellationToken).ConfigureAwait(false);
                await InvalidateSchemaValidationAndReviewAsync(
                    targetConnection,
                    targetTx,
                    runGuid,
                    context.CancellationToken).ConfigureAwait(false);

                await AddSchemaExecutionLogAsync(
                    targetConnection,
                    targetTx,
                    runGuid,
                    "Exclusion",
                    request.IsExcluded ? "Excluded" : "Unexcluded",
                    request.IsExcluded
                        ? $"Schema object {objectIdentity.DisplayName} was excluded globally from the source-authoritative comparison policy and synchronized to the target."
                        : $"Schema object {objectIdentity.DisplayName} was removed from the source-authoritative exclusion policy and synchronized to the target.",
                    JsonSerializer.Serialize(new
                    {
                        exclusionGuid,
                        objectIdentity.ObjectType,
                        objectIdentity.SchemaName,
                        objectIdentity.ObjectName,
                        objectIdentity.ParentObjectName,
                        Reason = reason,
                        request.IsExcluded,
                        SourceServerName = sourceConnection.DataSource,
                        SourceDatabaseName = sourceConnection.Database,
                        TargetServerName = targetConnection.DataSource,
                        TargetDatabaseName = targetConnection.Database,
                        Scope = "AllDatabases"
                    }),
                    context.CancellationToken).ConfigureAwait(false);

                await targetTx.CommitAsync(context.CancellationToken).ConfigureAwait(false);
            }
            catch
            {
                await targetTx.RollbackAsync(context.CancellationToken).ConfigureAwait(false);
                throw;
            }

            var activeCount = (await ReadSchemaExcludedObjectRecordsAsync(
                sourceConnection,
                includeInactive: false,
                context.CancellationToken).ConfigureAwait(false)).Count;

            return new SchemaMigrationExclusionResponse
            {
                ExcludedCount = activeCount,
                Message = request.IsExcluded
                    ? $"{objectIdentity.DisplayName} is excluded for all future schema datasets. The source policy was synchronized to {targetConnection.Database}; rerun compare to refresh the current run."
                    : $"{objectIdentity.DisplayName} is no longer excluded. The source policy was synchronized to {targetConnection.Database}; rerun compare to include it again."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Schema exclusion SQL failed: {ex.Message}"));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new RpcException(new Status(StatusCode.Internal, $"Schema exclusion failed: {ex.Message}"));
        }
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
        response.Rows.AddRange((await ReadSchemaComparisonRowsAsync(
            cn,
            runGuid,
            request.ObjectType,
            request.DifferenceType,
            request.SearchText,
            request.IncludeDefinitions,
            comparisonGuid,
            context.CancellationToken).ConfigureAwait(false)).Select(ToSchemaComparisonRow));
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
                    "Schema deployment selection cleared. The plan is empty; validation and deployment acceptance were reset.",
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
                Message = "Selection cleared. No schema differences are included. Select and save at least one deployable row before validation.",
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
            var counts = await SchemaEngine.SaveSelectionAsync(
                request.TargetServerName,
                request.TargetDatabaseName,
                runGuid,
                request.Selections
                    .Select(x => new SchemaSelectionRequestItem
                    {
                        ComparisonGuid = x.ComparisonGuid,
                        ObjectType = x.ObjectType,
                        SchemaName = x.SchemaName,
                        ObjectName = x.ObjectName,
                        ParentObjectName = x.ParentObjectName,
                        IsSelected = x.IsSelected,
                        CopyReferenceData = x.CopyReferenceData
                    })
                    .ToList(),
                request.Notes,
                context.CancellationToken).ConfigureAwait(false);
            return new SchemaMigrationSelectionResponse
            {
                Success = true,
                Message = $"Schema deployment selection saved. {counts.SelectedCount:N0} of {counts.DeployableCount:N0} deployable differences are selected. Revalidate and accept the updated plan before deployment.",
                SelectedCount = counts.SelectedCount,
                DeployableCount = counts.DeployableCount,
                ExplicitSelectionCount = counts.ExplicitSelectionCount
            };
        }
        catch (SchemaMigrationException ex)
        {
            throw ToSchemaRpcException(ex);
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
            var result = await SchemaEngine.AcceptAsync(
                request.TargetServerName,
                request.TargetDatabaseName,
                runGuid,
                request.ReviewedByNote,
                context.CancellationToken).ConfigureAwait(false);
            return new SchemaMigrationOperationResponse
            {
                Success = result.Success,
                Message = result.Message
            };
        }
        catch (SchemaMigrationException ex)
        {
            throw ToSchemaRpcException(ex);
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
                    cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, -1) { Value = request.Notes ?? string.Empty });
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

    private Task<SqlConnection> OpenSchemaTargetSqlAsync(string targetServerName, string targetDatabaseName, CancellationToken cancellationToken) =>
        SchemaEngine.OpenTargetSqlAsync(targetServerName, targetDatabaseName, cancellationToken);

    // Adapters over the shared engine. They keep the pre-extraction gRPC contract: a missing run is
    // RpcException NotFound and a failed prerequisite install is RpcException FailedPrecondition,
    // raised at the same point in each RPC as before.
    private static async Task<SchemaRunRecord> ReadSchemaRunSummaryAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        try
        {
            return await SchemaMigrationEngine.ReadSchemaRunSummaryAsync(cn, runGuid, cancellationToken).ConfigureAwait(false);
        }
        catch (SchemaMigrationException ex)
        {
            throw ToSchemaRpcException(ex);
        }
    }

    private async Task EnsureSchemaExclusionInfrastructureAsync(
        string location,
        string configuredServerName,
        string configuredDatabaseName,
        string configuredEnvironmentName,
        CancellationToken cancellationToken)
    {
        try
        {
            await SchemaEngine.EnsureSchemaExclusionInfrastructureAsync(
                location,
                configuredServerName,
                configuredDatabaseName,
                configuredEnvironmentName,
                cancellationToken).ConfigureAwait(false);
        }
        catch (SchemaMigrationException ex)
        {
            throw ToSchemaRpcException(ex);
        }
    }

    private static async Task<SchemaMigrationValidateResponse> ReadSchemaValidationResponseAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken) =>
        ToSchemaValidateResponse(await ReadSchemaValidationAsync(cn, runGuid, cancellationToken).ConfigureAwait(false));

    private static SchemaMigrationValidateResponse ToSchemaValidateResponse(SchemaValidationResult validation)
    {
        var response = new SchemaMigrationValidateResponse
        {
            FailCount = validation.FailCount,
            WarnCount = validation.WarnCount,
            InfoCount = validation.InfoCount
        };

        foreach (var issue in validation.ValidationIssues)
        {
            response.ValidationIssues.Add(new SchemaMigrationValidationIssue
            {
                IssueGuid = issue.IssueGuid,
                ComparisonGuid = issue.ComparisonGuid,
                Severity = issue.Severity,
                IssueCode = issue.IssueCode,
                IssueMessage = issue.IssueMessage,
                ObjectType = issue.ObjectType,
                SchemaName = issue.SchemaName,
                ObjectName = issue.ObjectName,
                DetailsJson = issue.DetailsJson
            });
        }

        return response;
    }

    private static SchemaMigrationRunSummary ToSchemaRunSummary(SchemaRunRecord run) =>
        new()
        {
            RunGuid = run.RunGuid,
            SourceEnvironment = run.SourceEnvironment,
            TargetEnvironment = run.TargetEnvironment,
            SourceServerName = run.SourceServerName,
            SourceDatabaseName = run.SourceDatabaseName,
            TargetServerName = run.TargetServerName,
            TargetDatabaseName = run.TargetDatabaseName,
            JiraReference = run.JiraReference,
            ReleaseReference = run.ReleaseReference,
            RunStatus = run.RunStatus,
            IsReviewed = run.IsReviewed,
            CreatedOnUtc = run.CreatedOnUtc,
            ComparedOnUtc = run.ComparedOnUtc,
            ValidatedOnUtc = run.ValidatedOnUtc,
            ReviewedOnUtc = run.ReviewedOnUtc,
            AppliedOnUtc = run.AppliedOnUtc,
            Notes = run.Notes,
            SummaryJson = run.SummaryJson,
            SourceSyncedOnUtc = run.SourceSyncedOnUtc,
            SourceSyncCommit = run.SourceSyncCommit
        };

    private static SchemaMigrationObjectComparisonRow ToSchemaComparisonRow(SchemaComparisonRowRecord row) =>
        new()
        {
            ComparisonGuid = row.ComparisonGuid,
            ObjectType = row.ObjectType,
            SchemaName = row.SchemaName,
            ObjectName = row.ObjectName,
            ParentObjectName = row.ParentObjectName,
            DifferenceType = row.DifferenceType,
            IsDeployable = row.IsDeployable,
            IsDestructiveRisk = row.IsDestructiveRisk,
            SourceHash = row.SourceHash,
            TargetHash = row.TargetHash,
            SourceDefinition = row.SourceDefinition,
            TargetDefinition = row.TargetDefinition,
            Notes = row.Notes,
            IsSelected = row.IsSelected,
            HasExplicitSelection = row.HasExplicitSelection,
            CopyReferenceData = row.CopyReferenceData
        };

    private static async Task<int> ReadSchemaCurrentUserIdAsync(SqlConnection cn, CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand("SELECT ISNULL([SCore].[GetCurrentUserId](), -1);", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        var value = await cmd.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false);
        return value is null || value == DBNull.Value ? -1 : Convert.ToInt32(value);
    }

    private static SchemaMigrationExcludedObject MapSchemaExcludedObject(
        SchemaExcludedObjectRecord sourceRecord,
        SchemaExcludedObjectRecord? targetRecord)
    {
        var sourceActive = sourceRecord.IsActive;
        var targetMatches = !sourceActive && targetRecord is null
            || targetRecord is not null
               && targetRecord.IsActive == sourceActive
               && (!sourceActive || targetRecord.Reason.Equals(sourceRecord.Reason, StringComparison.Ordinal))
               && targetRecord.StableObjectKey.Equals(sourceRecord.StableObjectKey, StringComparison.OrdinalIgnoreCase);

        return new SchemaMigrationExcludedObject
        {
            Guid = sourceRecord.Guid.ToString(),
            ObjectType = sourceRecord.ObjectType,
            SchemaName = sourceRecord.SchemaName,
            ObjectName = sourceRecord.ObjectName,
            ParentObjectName = sourceRecord.ParentObjectName,
            StableObjectKey = sourceRecord.StableObjectKey,
            Reason = sourceRecord.Reason,
            ExclusionScope = sourceRecord.ExclusionScope,
            OriginServerName = sourceRecord.OriginServerName,
            OriginDatabaseName = sourceRecord.OriginDatabaseName,
            ExcludedByUserId = sourceRecord.ExcludedByUserId,
            ExcludedOnUtc = sourceRecord.ExcludedOnUtc,
            UnexcludedOnUtc = sourceRecord.UnexcludedOnUtc,
            LastSeenRunGuid = sourceRecord.LastSeenRunGuid == Guid.Empty ? string.Empty : sourceRecord.LastSeenRunGuid.ToString(),
            LastSeenOnUtc = sourceRecord.LastSeenOnUtc,
            RowStatus = sourceRecord.RowStatus,
            IsSynchronizedToTarget = targetMatches
        };
    }

    private static async Task<SchemaObjectIdentity> ResolveSchemaExclusionObjectIdentityAsync(
        SqlConnection targetConnection,
        Guid runGuid,
        SchemaMigrationExclusionUpsertRequest request,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(request.ComparisonGuid))
        {
            var comparisonGuid = ParseGuid(request.ComparisonGuid, "comparisonGuid");
            var rows = await ReadSchemaComparisonRowsAsync(
                targetConnection,
                runGuid,
                string.Empty,
                string.Empty,
                string.Empty,
                includeDefinitions: false,
                comparisonGuid,
                cancellationToken).ConfigureAwait(false);
            var comparison = rows.FirstOrDefault();
            if (comparison is null)
            {
                throw new RpcException(new Status(StatusCode.NotFound, "The selected schema comparison row was not found or is already excluded."));
            }

            return new SchemaObjectIdentity(
                comparison.ObjectType,
                comparison.SchemaName,
                comparison.ObjectName,
                comparison.ParentObjectName);
        }

        var identity = new SchemaObjectIdentity(
            request.ObjectType ?? string.Empty,
            request.SchemaName ?? string.Empty,
            request.ObjectName ?? string.Empty,
            request.ParentObjectName ?? string.Empty);
        if (!identity.IsValid)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, "Schema exclusion object identity is incomplete."));
        }

        return identity;
    }

    private static async Task DeactivateSchemaSelectionForObjectAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid runGuid,
        SchemaObjectIdentity objectIdentity,
        CancellationToken cancellationToken)
    {
        var selectionGuids = new List<Guid>();
        await using (var readCommand = new SqlCommand(@"
SELECT
    selection.[Guid]
FROM [SMigration].[Schema_RunSelections] AS selection
WHERE selection.[RunGuid] = @RunGuid
  AND selection.[ObjectType] = @ObjectType
  AND selection.[SchemaName] = @SchemaName
  AND selection.[ObjectName] = @ObjectName
  AND selection.[ParentObjectName] = @ParentObjectName
  AND selection.[RowStatus] <> 0
  AND selection.[RowStatus] <> 254;", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        })
        {
            readCommand.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            readCommand.Parameters.Add(new SqlParameter("@ObjectType", SqlDbType.NVarChar, 50) { Value = objectIdentity.ObjectType });
            readCommand.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = objectIdentity.SchemaName });
            readCommand.Parameters.Add(new SqlParameter("@ObjectName", SqlDbType.NVarChar, 512) { Value = objectIdentity.ObjectName });
            readCommand.Parameters.Add(new SqlParameter("@ParentObjectName", SqlDbType.NVarChar, 512) { Value = objectIdentity.ParentObjectName });
            await using var reader = await readCommand.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                selectionGuids.Add(reader.GetGuid(0));
            }
        }

        foreach (var selectionGuid in selectionGuids)
        {
            await using var deleteCommand = new SqlCommand("SCore.DeleteDataObject", cn, tx)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };
            deleteCommand.Parameters.Add(new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = selectionGuid });
            await deleteCommand.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        await using var updateCommand = new SqlCommand(@"
UPDATE [SMigration].[Schema_RunSelections]
SET [RowStatus] = 254
WHERE [RunGuid] = @RunGuid
  AND [ObjectType] = @ObjectType
  AND [SchemaName] = @SchemaName
  AND [ObjectName] = @ObjectName
  AND [ParentObjectName] = @ParentObjectName
  AND [RowStatus] <> 0
  AND [RowStatus] <> 254;", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        updateCommand.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        updateCommand.Parameters.Add(new SqlParameter("@ObjectType", SqlDbType.NVarChar, 50) { Value = objectIdentity.ObjectType });
        updateCommand.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = objectIdentity.SchemaName });
        updateCommand.Parameters.Add(new SqlParameter("@ObjectName", SqlDbType.NVarChar, 512) { Value = objectIdentity.ObjectName });
        updateCommand.Parameters.Add(new SqlParameter("@ParentObjectName", SqlDbType.NVarChar, 512) { Value = objectIdentity.ParentObjectName });
        await updateCommand.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    private static async Task<SchemaMigrationDashboardMessage> ReadSchemaDashboardAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        var dashboard = new SchemaMigrationDashboardMessage
        {
            Run = ToSchemaRunSummary(await ReadSchemaRunSummaryAsync(cn, runGuid, cancellationToken).ConfigureAwait(false))
        };

        await using (var cmd = new SqlCommand(@"
SELECT
    c.DifferenceType,
    COUNT_BIG(1) AS [RowCount]
FROM SMigration.Schema_ObjectComparisons AS c
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

        await using (var excludedCountCommand = new SqlCommand(@"
SELECT COUNT_BIG(1)
FROM SMigration.Schema_ExcludedObjects AS excluded
WHERE excluded.RowStatus <> 0
  AND excluded.RowStatus <> 254;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        })
        {
            dashboard.ExcludedCount = Convert.ToInt32(
                await excludedCountCommand.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false) ?? 0L);
        }

        var validation = await ReadSchemaValidationResponseAsync(cn, runGuid, cancellationToken).ConfigureAwait(false);
        dashboard.FailCount = validation.FailCount;
        dashboard.WarnCount = validation.WarnCount;
        dashboard.InfoCount = validation.InfoCount;
        dashboard.ValidationIssues.AddRange(validation.ValidationIssues);
        dashboard.ExecutionLog.AddRange(await ReadSchemaExecutionLogAsync(cn, runGuid, cancellationToken).ConfigureAwait(false));

        return dashboard;
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

    private static async Task<List<SchemaMigrationObjectComparisonRow>> ReadSchemaDeploymentPlanRowsAsync(
        SqlConnection cn,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        var rows = new List<SchemaMigrationObjectComparisonRow>();
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
    CONVERT(NVARCHAR(MAX), N'') AS SourceDefinition,
    CONVERT(NVARCHAR(MAX), N'') AS TargetDefinition,
    c.Notes,
    CONVERT(BIT, 1) AS IsSelected,
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
                HasExplicitSelection = reader.GetBoolean(14),
                CopyReferenceData = reader.GetBoolean(15)
            });
        }

        return rows;
    }
}
