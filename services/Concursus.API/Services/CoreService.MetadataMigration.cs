using Concursus.API.Core;
using Google.Protobuf.Collections;
using Grpc.Core;
using static Concursus.EF.MetadataMigration.MetadataTwoConnectionStaging;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Concursus.API.Services;

public partial class CoreService
{
    [Microsoft.AspNetCore.Authorization.Authorize(Roles = "User.ReadWrite,SysAdmin")]
    public override async Task<MetadataMigrationRunResponse> MetadataMigrationRunCreate(
        MetadataMigrationRunCreateRequest request,
        ServerCallContext context)
    {
        try
        {
            var bootstrap = await _migrationBootstrapRepository.EnsureMetadataWorkbenchAsync(
                request.TargetServerName,
                request.TargetDatabaseName,
                request.TargetEnvironment,
                context.CancellationToken);

            await using var templateConnection = await OpenSqlAsync(context.CancellationToken);
            await using var cn = await OpenSqlForServerDatabaseAsync(
                templateConnection.ConnectionString,
                request.TargetServerName,
                request.TargetDatabaseName,
                context.CancellationToken);

            await ExecuteNonQueryAsync(cn, "SMigration.MetadataRegistry_Seed", context.CancellationToken);

            await using var transaction = (SqlTransaction)await cn
                .BeginTransactionAsync(context.CancellationToken)
                .ConfigureAwait(false);

            try
            {
                await using var cmd = new SqlCommand("SMigration.MetadataRun_Create", cn, transaction)
                {
                    CommandType = CommandType.StoredProcedure,
                    CommandTimeout = 300
                };

                var runGuid = Guid.Empty;

                cmd.Parameters.Add(new SqlParameter("@SourceEnvironment", SqlDbType.NVarChar, 20) { Value = request.SourceEnvironment ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@TargetEnvironment", SqlDbType.NVarChar, 20) { Value = request.TargetEnvironment ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@SourceServerName", SqlDbType.NVarChar, 255) { Value = request.SourceServerName ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@SourceDatabaseName", SqlDbType.NVarChar, 255) { Value = request.SourceDatabaseName ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@TargetServerName", SqlDbType.NVarChar, 255) { Value = request.TargetServerName ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@TargetDatabaseName", SqlDbType.NVarChar, 255) { Value = request.TargetDatabaseName ?? string.Empty });
                cmd.Parameters.Add(new SqlParameter("@IsValidateOnly", SqlDbType.Bit) { Value = request.IsValidateOnly });

                var runGuidParameter = new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier)
                {
                    Direction = ParameterDirection.Output
                };
                cmd.Parameters.Add(runGuidParameter);

                await cmd.ExecuteNonQueryAsync(context.CancellationToken);

                if (runGuidParameter.Value is Guid parsedRunGuid)
                {
                    runGuid = parsedRunGuid;
                }

                if (runGuid == Guid.Empty)
                {
                    throw new InvalidOperationException("Metadata run creation returned an empty run Guid.");
                }

                if (bootstrap.WasApplied)
                {
                    await AddExecutionLogAsync(
                        cn,
                        transaction,
                        runGuid,
                        "BootstrapTarget",
                        "Applied",
                        "Metadata Migration target prerequisites were installed from source-controlled SQL.",
                        JsonSerializer.Serialize(new
                        {
                            bootstrap.BootstrapKind,
                            bootstrap.EnvironmentName,
                            DatabaseRole = "Target",
                            bootstrap.ServerName,
                            bootstrap.DatabaseName,
                            bootstrap.MissingBefore,
                            bootstrap.MissingAfter,
                            bootstrap.InstalledObjects,
                            bootstrap.ScriptSha256,
                            bootstrap.DivergentModules
                        }),
                        context.CancellationToken);
                }

                await transaction.CommitAsync(context.CancellationToken).ConfigureAwait(false);

                return new MetadataMigrationRunResponse
                {
                    Run = await ReadRunSummaryAsync(cn, runGuid, context.CancellationToken)
                };
            }
            catch
            {
                try
                {
                    if (transaction.Connection is not null)
                    {
                        await transaction.RollbackAsync(CancellationToken.None).ConfigureAwait(false);
                    }
                }
                catch (InvalidOperationException)
                {
                    // SQL Server already completed or rolled back the transaction.
                }

                throw;
            }
        }
        catch (Concursus.EF.MigrationBootstrapRepository.MigrationBootstrapException ex)
        {
            throw new RpcException(new Status(StatusCode.FailedPrecondition, ex.Message));
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata run create SQL failed: {ex.Message}"));
        }
        catch (Exception ex)
        {
            throw new RpcException(new Status(StatusCode.Internal, $"Metadata run create failed: {ex.Message}"));
        }
    }

    [Microsoft.AspNetCore.Authorization.Authorize(Roles = "User.ReadWrite,SysAdmin")]
    public override async Task<MetadataMigrationRunsResponse> MetadataMigrationRuns(
        MetadataMigrationRunsRequest request,
        ServerCallContext context)
    {
        try
        {
            await _migrationBootstrapRepository.EnsureMetadataWorkbenchAsync(
                request.TargetServerName,
                request.TargetDatabaseName,
                string.Empty,
                context.CancellationToken).ConfigureAwait(false);
        }
        catch (Concursus.EF.MigrationBootstrapRepository.MigrationBootstrapException ex)
        {
            throw new RpcException(new Status(StatusCode.FailedPrecondition, ex.Message));
        }

        var response = new MetadataMigrationRunsResponse();
        var top = request.Top <= 0 ? 50 : Math.Min(request.Top, 200);

        await using var templateConnection = await OpenSqlAsync(context.CancellationToken);
        await using var cn = await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);

        await using var cmd = new SqlCommand(@"
SELECT TOP (@Top)
    r.Guid,
    r.SourceEnvironment,
    r.TargetEnvironment,
    r.SourceServerName,
    r.SourceDatabaseName,
    r.TargetServerName,
    r.TargetDatabaseName,
    r.RunStatus,
    r.IsValidateOnly,
    r.CreatedOnUtc,
    r.ValidatedOnUtc,
    r.AppliedOnUtc,
    r.SummaryJson
FROM SMigration.Metadata_Run AS r
WHERE r.RowStatus NOT IN (0,254)
ORDER BY r.ID DESC;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@Top", SqlDbType.Int) { Value = top });

        await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
        while (await reader.ReadAsync(context.CancellationToken))
        {
            response.Runs.Add(MapRunSummary(reader));
        }

        return response;
    }

    public override async Task<MetadataMigrationRunResponse> MetadataMigrationRunGet(
        MetadataMigrationRunRequest request,
        ServerCallContext context)
    {
        await using var cn = await OpenTargetSqlFromRequestAsync(request, context.CancellationToken);
        return new MetadataMigrationRunResponse
        {
            Run = await ReadRunSummaryAsync(cn, ParseGuid(request.RunGuid, "runGuid"), context.CancellationToken)
        };
    }

    public override async Task<MetadataMigrationStageResponse> MetadataMigrationStage(
        MetadataMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var targetConnection = await OpenTargetSqlFromRequestAsync(request, context.CancellationToken);
            var run = await ReadRunSummaryAsync(targetConnection, runGuid, context.CancellationToken);

            if (IsSameSqlServer(run.SourceServerName, run.TargetServerName))
            {
                await ExecuteRunProcedureAsync(
                    targetConnection,
                    "SMigration.MetadataStage_Run",
                    runGuid,
                    context.CancellationToken,
                    includeRetirements: request.IncludeRetirements);
            }
            else
            {
                await using var sourceConnection = await OpenSqlForServerDatabaseAsync(
                    targetConnection.ConnectionString,
                    run.SourceServerName,
                    run.SourceDatabaseName,
                    context.CancellationToken);

                await StageMetadataWithTwoConnectionsAsync(
                    sourceConnection,
                    targetConnection,
                    runGuid,
                    request.IncludeRetirements,
                    context.CancellationToken);
            }

            return new MetadataMigrationStageResponse
            {
                StagedCounts = { await ReadStagedCountsAsync(targetConnection, runGuid, context.CancellationToken) }
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata stage SQL failed: {ex.Message}"));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (MetadataStagingException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, ex.Message));
        }
        catch (Exception ex)
        {
            var message = ex.InnerException is null
                ? ex.Message
                : $"{ex.Message} Inner: {ex.InnerException.Message}";

            throw new RpcException(new Status(StatusCode.Internal, $"Metadata stage failed: {message}"));
        }
    }

    public override async Task<MetadataMigrationValidateResponse> MetadataMigrationValidate(
        MetadataMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenTargetSqlFromRequestAsync(request, context.CancellationToken);
            await ExecuteRunProcedureAsync(cn, "SMigration.MetadataValidate_Run", runGuid, context.CancellationToken);
            return await ReadValidationAsync(cn, runGuid, context.CancellationToken);
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata validate SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationValidationIssueIgnoreResponse> MetadataMigrationValidationIssueIgnoreUpsert(
        MetadataMigrationValidationIssueIgnoreUpsertRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        var validationIssueGuid = ParseGuid(request.ValidationIssueGuid, "validationIssueGuid");

        try
        {
            await _metadataMigrationRepository.UpsertValidationIssueIgnoreAsync(
                runGuid,
                validationIssueGuid,
                request.IsIgnored,
                request.Reason ?? string.Empty,
                request.TargetServerName ?? string.Empty,
                request.TargetDatabaseName ?? string.Empty,
                context.CancellationToken).ConfigureAwait(false);

            await using var connection = await OpenTargetSqlFromRequestAsync(
                new MetadataMigrationRunRequest
                {
                    RunGuid = request.RunGuid,
                    TargetServerName = request.TargetServerName,
                    TargetDatabaseName = request.TargetDatabaseName
                },
                context.CancellationToken);

            var validation = await ReadValidationAsync(connection, runGuid, context.CancellationToken);
            return new MetadataMigrationValidationIssueIgnoreResponse
            {
                ActiveFailCount = validation.FailCount,
                IgnoredIssueCount = validation.ValidationIssues.Count(issue => issue.IsIgnored),
                Message = request.IsIgnored
                    ? "Metadata validation issue ignored. Revalidate the selected rows before generating a new preview."
                    : "Metadata validation issue restored. Revalidate the selected rows before generating a new preview."
            };
        }
        catch (ArgumentException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, ex.Message));
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata validation issue ignore SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationBuildIdentityMapResponse> MetadataMigrationBuildIdentityMap(
        MetadataMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenTargetSqlFromRequestAsync(request, context.CancellationToken);
            var run = await ReadRunSummaryAsync(cn, runGuid, context.CancellationToken);

            if (IsSameSqlServer(run.SourceServerName, run.TargetServerName))
            {
                await ExecuteRunProcedureAsync(cn, "SMigration.MetadataApplyIdentityMap_Build", runGuid, context.CancellationToken);
            }
            else
            {
                // Same cross-server gap as staging: MetadataApplyIdentityMap_Build's own
                // registry sync can only resolve a source database on the SAME SQL Server
                // instance via DB_ID(). Do the real source-authoritative sync here first, over
                // two genuine connections, then tell the proc to skip its own (same-server-only)
                // sync so it doesn't immediately re-disable what this just correctly enabled.
                await using var sourceConnection = await OpenSqlForServerDatabaseAsync(
                    cn.ConnectionString,
                    run.SourceServerName,
                    run.SourceDatabaseName,
                    context.CancellationToken);

                await SyncMetadataRegistryFromEntityTypesAsync(sourceConnection, cn, runGuid, context.CancellationToken);
                await ExecuteRunProcedureAsync(cn, "SMigration.MetadataApplyIdentityMap_Build", runGuid, context.CancellationToken, skipRegistrySync: true);
            }

            var response = new MetadataMigrationBuildIdentityMapResponse();
            response.Rows.AddRange(await ReadIdentityMapAsync(cn, runGuid, context.CancellationToken));
            return response;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata identity map SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationIdentityMapReviewResponse> MetadataMigrationIdentityMapReviewSet(
        MetadataMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenTargetSqlFromRequestAsync(request, context.CancellationToken);
            await using var cmd = new SqlCommand("SMigration.MetadataExecutionLog_Add", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            cmd.Parameters.Add(new SqlParameter("@StepName", SqlDbType.NVarChar, 100) { Value = "IdentityMapReview" });
            cmd.Parameters.Add(new SqlParameter("@StepStatus", SqlDbType.NVarChar, 30) { Value = "Reviewed" });
            cmd.Parameters.Add(new SqlParameter("@Message", SqlDbType.NVarChar, 2000) { Value = "Identity map missing target rows reviewed and acknowledged." });
            cmd.Parameters.Add(new SqlParameter("@DetailsJson", SqlDbType.NVarChar, -1) { Value = "{}" });

            await cmd.ExecuteNonQueryAsync(context.CancellationToken);

            return new MetadataMigrationIdentityMapReviewResponse
            {
                IsReviewed = true,
                Message = "Identity map review acknowledged."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata identity map review SQL failed: {ex.Message}"));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            var message = ex.InnerException is null
                ? ex.Message
                : $"{ex.Message} Inner: {ex.InnerException.Message}";

            throw new RpcException(new Status(StatusCode.Internal, $"Metadata identity map review failed: {message}"));
        }
    }

    public override async Task<MetadataMigrationIdentityMapDetailsResponse> MetadataMigrationIdentityMapDetails(
        MetadataMigrationIdentityMapDetailsRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var templateConnection = await OpenSqlAsync(context.CancellationToken);
            await using var cn = await OpenSqlForServerDatabaseAsync(
                templateConnection.ConnectionString,
                request.TargetServerName,
                request.TargetDatabaseName,
                context.CancellationToken);

            return await ReadIdentityMapDetailsAsync(
                cn,
                runGuid,
                request.SchemaName ?? string.Empty,
                request.TableName ?? string.Empty,
                request.IncludeIgnored,
                context.CancellationToken);
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata identity map detail SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationIdentityMapIssueResponse> MetadataMigrationIdentityMapIssueUpsert(
        MetadataMigrationIdentityMapIssueUpsertRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        var sourceRowGuid = ParseGuid(request.SourceRowGuid, "sourceRowGuid");

        try
        {
            await using var templateConnection = await OpenSqlAsync(context.CancellationToken);
            await using var cn = await OpenSqlForServerDatabaseAsync(
                templateConnection.ConnectionString,
                request.TargetServerName,
                request.TargetDatabaseName,
                context.CancellationToken);

            await using var cmd = new SqlCommand("SMigration.MetadataIdentityMapIssue_Upsert", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = request.SchemaName ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = request.TableName ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@SourceRowGuid", SqlDbType.UniqueIdentifier) { Value = sourceRowGuid });
            cmd.Parameters.Add(new SqlParameter("@Reason", SqlDbType.NVarChar, 500) { Value = request.Reason ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@IsIgnored", SqlDbType.Bit) { Value = request.IsIgnored });

            await cmd.ExecuteNonQueryAsync(context.CancellationToken);

            var details = await ReadIdentityMapDetailsAsync(
                cn,
                runGuid,
                request.SchemaName ?? string.Empty,
                request.TableName ?? string.Empty,
                includeIgnored: true,
                cancellationToken: context.CancellationToken);

            return new MetadataMigrationIdentityMapIssueResponse
            {
                UnresolvedCount = details.UnresolvedCount,
                IgnoredCount = details.IgnoredCount,
                Message = request.IsIgnored
                    ? $"Identity map issue ignored. {details.UnresolvedCount} unresolved issue(s), {details.IgnoredCount} ignored issue(s)."
                    : $"Identity map issue unignored. {details.UnresolvedCount} unresolved issue(s), {details.IgnoredCount} ignored issue(s)."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata identity map issue SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationIdentityMapCandidatesResponse> MetadataMigrationIdentityMapCandidates(
        MetadataMigrationIdentityMapCandidatesRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        var sourceRowGuid = ParseGuid(request.SourceRowGuid, "sourceRowGuid");
        var response = new MetadataMigrationIdentityMapCandidatesResponse();

        try
        {
            await using var templateConnection = await OpenSqlAsync(context.CancellationToken);
            await using var cn = await OpenSqlForServerDatabaseAsync(
                templateConnection.ConnectionString,
                request.TargetServerName,
                request.TargetDatabaseName,
                context.CancellationToken);

            var contextRow = await ReadIdentityMapSourceContextAsync(
                cn,
                runGuid,
                request.SchemaName ?? string.Empty,
                request.TableName ?? string.Empty,
                sourceRowGuid,
                context.CancellationToken);

            response.SourcePayloadJson = contextRow.SourcePayloadJson;
            var sourceValues = ParseJsonDictionary(contextRow.SourcePayloadJson);
            response.SourceDisplayName = GetMetadataDisplayValue(sourceValues, sourceRowGuid.ToString());

            var columns = await ReadStageColumnNamesAsync(
                cn,
                null,
                contextRow.Registry.SchemaName,
                contextRow.Registry.TableName,
                context.CancellationToken);

            var targetRows = await ReadMetadataPayloadRowsAsync(
                cn,
                null,
                contextRow.Registry,
                columns,
                activeOnly: true,
                context.CancellationToken);

            var searchText = (request.SearchText ?? string.Empty).Trim();
            var candidates = targetRows
                .Where(row => row.RowGuid != sourceRowGuid)
                .Select(row =>
                {
                    var targetValues = ParseJsonDictionary(row.PayloadJson);
                    var score = ScoreIdentityMapCandidate(sourceValues, targetValues, searchText, out var reason);
                    return new
                    {
                        Row = row,
                        Values = targetValues,
                        Score = score,
                        Reason = reason,
                        DisplayName = GetMetadataDisplayValue(targetValues, row.RowGuid.ToString())
                    };
                })
                .Where(candidate => candidate.Score > 0)
                .OrderByDescending(candidate => candidate.Score)
                .ThenBy(candidate => candidate.DisplayName, StringComparer.OrdinalIgnoreCase)
                .Take(25)
                .ToList();

            foreach (var candidate in candidates)
            {
                response.Rows.Add(new MetadataMigrationIdentityMapCandidateRow
                {
                    TargetRowGuid = candidate.Row.RowGuid.ToString(),
                    TargetRowId = candidate.Row.RowId ?? 0,
                    TargetDisplayName = candidate.DisplayName,
                    MatchReason = candidate.Reason,
                    MatchScore = candidate.Score,
                    TargetPayloadJson = candidate.Row.PayloadJson
                });
            }

            return response;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata identity map candidate SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationIdentityMapIssueResponse> MetadataMigrationIdentityMapOverrideUpsert(
        MetadataMigrationIdentityMapOverrideUpsertRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        var sourceRowGuid = ParseGuid(request.SourceRowGuid, "sourceRowGuid");
        var targetRowGuid = request.IsActive
            ? ParseGuid(request.TargetRowGuid, "targetRowGuid")
            : Guid.Empty;

        try
        {
            await using var templateConnection = await OpenSqlAsync(context.CancellationToken);
            await using var cn = await OpenSqlForServerDatabaseAsync(
                templateConnection.ConnectionString,
                request.TargetServerName,
                request.TargetDatabaseName,
                context.CancellationToken);

            await using var cmd = new SqlCommand("SMigration.MetadataIdentityMapOverride_Upsert", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = request.SchemaName ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = request.TableName ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@SourceRowGuid", SqlDbType.UniqueIdentifier) { Value = sourceRowGuid });
            cmd.Parameters.Add(new SqlParameter("@TargetRowGuid", SqlDbType.UniqueIdentifier) { Value = request.IsActive ? (object)targetRowGuid : DBNull.Value });
            cmd.Parameters.Add(new SqlParameter("@Reason", SqlDbType.NVarChar, 500) { Value = request.Reason ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@IsActive", SqlDbType.Bit) { Value = request.IsActive });
            cmd.Parameters.Add(new SqlParameter("@ColumnSourceSelectionJson", SqlDbType.NVarChar, -1)
            {
                Value = request.IsActive && !string.IsNullOrWhiteSpace(request.ColumnSourceSelectionJson)
                    ? request.ColumnSourceSelectionJson
                    : (object)DBNull.Value
            });

            await cmd.ExecuteNonQueryAsync(context.CancellationToken);

            var details = await ReadIdentityMapDetailsAsync(
                cn,
                runGuid,
                request.SchemaName ?? string.Empty,
                request.TableName ?? string.Empty,
                includeIgnored: true,
                cancellationToken: context.CancellationToken);

            return new MetadataMigrationIdentityMapIssueResponse
            {
                UnresolvedCount = details.UnresolvedCount,
                IgnoredCount = details.IgnoredCount,
                Message = request.IsActive
                    ? $"Manual identity map override saved. {details.UnresolvedCount} unresolved issue(s), {details.IgnoredCount} ignored issue(s)."
                    : $"Manual identity map override cleared. {details.UnresolvedCount} unresolved issue(s), {details.IgnoredCount} ignored issue(s)."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata identity map override SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationApplyResponse> MetadataMigrationApply(
        MetadataMigrationApplyRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        if (!request.ApplySelectedOnly)
        {
            throw new RpcException(new Status(
                StatusCode.FailedPrecondition,
                "Metadata apply is selected-only. Select and preview at least one metadata row before apply."));
        }

        try
        {
            await _metadataMigrationRepository.ApplyAsync(
                runGuid,
                request.ForceApply,
                request.ApplySelectedOnly,
                request.TargetServerName ?? string.Empty,
                request.TargetDatabaseName ?? string.Empty,
                context.CancellationToken).ConfigureAwait(false);

            return new MetadataMigrationApplyResponse
            {
                Message = "Selected metadata records applied successfully."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata apply SQL failed: {ex.Message}"));
        }
        catch (Concursus.EF.MetadataMigrationRepository.MetadataMigrationDriftException ex)
        {
            throw new RpcException(new Status(StatusCode.FailedPrecondition, ex.Message));
        }
        catch (Exception ex) when (ex is ArgumentException or InvalidOperationException)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, ex.Message));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            var message = ex.InnerException is null
                ? ex.Message
                : $"{ex.Message} Inner: {ex.InnerException.Message}";

            throw new RpcException(new Status(StatusCode.Internal, $"Metadata apply failed: {message}"));
        }
    }

    public override async Task<MetadataMigrationApplyPreviewResponse> MetadataMigrationApplyPreview(
        MetadataMigrationApplyPreviewRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        if (!request.ApplySelectedOnly)
        {
            throw new RpcException(new Status(
                StatusCode.FailedPrecondition,
                "Metadata preview is selected-only. Select at least one metadata row before preview."));
        }

        var response = new MetadataMigrationApplyPreviewResponse
        {
            ApplySelectedOnly = request.ApplySelectedOnly
        };

        try
        {
            var preview = await _metadataMigrationRepository.GetApplyPreviewAsync(
                runGuid,
                request.ApplySelectedOnly,
                request.IncludeIgnored,
                request.TargetServerName ?? string.Empty,
                request.TargetDatabaseName ?? string.Empty,
                context.CancellationToken).ConfigureAwait(false);

            foreach (var previewRow in preview.Rows)
            {
                var row = new MetadataMigrationApplyPreviewRow
                {
                    SchemaName = previewRow.SchemaName,
                    TableName = previewRow.TableName,
                    SourceRowGuid = previewRow.SourceRowGuid.ToString(),
                    SourceRowId = previewRow.SourceRowId,
                    DifferenceType = previewRow.DifferenceType,
                    IsSelected = previewRow.IsSelected,
                    IsIgnored = previewRow.IsIgnored,
                    HasValidationFailure = previewRow.HasValidationFailure,
                    ApplyAction = previewRow.ApplyAction,
                    SkipReason = previewRow.SkipReason,
                    ChangedColumns = previewRow.ChangedColumns,
                    RunValidationFailureCount = previewRow.RunValidationFailureCount
                };

                response.Rows.Add(row);
            }

            response.PreviewFingerprint = preview.PreviewFingerprint;
            response.IsAccepted = preview.IsAccepted;
            response.AcceptedOnUtc = preview.AcceptedOnUtc;
            response.AcceptedByUserId = preview.AcceptedByUserId;

            response.ApplyCount = response.Rows.Count(row => row.ApplyAction.Equals("Apply", StringComparison.OrdinalIgnoreCase));
            response.BlockedCount = response.Rows.Count(row => row.ApplyAction.Equals("Blocked", StringComparison.OrdinalIgnoreCase));
            response.SkipCount = response.Rows.Count(row => row.ApplyAction.Equals("Skip", StringComparison.OrdinalIgnoreCase));
            response.IgnoredSkipCount = response.Rows.Count(row => row.IsIgnored && !row.ApplyAction.Equals("Apply", StringComparison.OrdinalIgnoreCase));
            response.RunValidationFailureCount = response.Rows.Count == 0 ? 0 : response.Rows.Max(row => row.RunValidationFailureCount);

            return response;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata apply preview SQL failed: {ex.Message}"));
        }
        catch (Concursus.EF.MetadataMigrationRepository.MetadataMigrationDriftException ex)
        {
            throw new RpcException(new Status(StatusCode.FailedPrecondition, ex.Message));
        }
        catch (Exception ex) when (ex is ArgumentException or InvalidOperationException)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, ex.Message));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            var message = ex.InnerException is null
                ? ex.Message
                : $"{ex.Message} Inner: {ex.InnerException.Message}";

            throw new RpcException(new Status(StatusCode.Internal, $"Metadata apply preview failed: {message}"));
        }
    }

    public override async Task<MetadataMigrationApplyPreviewAcceptResponse> MetadataMigrationApplyPreviewAccept(
        MetadataMigrationApplyPreviewAcceptRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        if (!request.ApplySelectedOnly)
        {
            throw new RpcException(new Status(
                StatusCode.FailedPrecondition,
                "Metadata preview acceptance is selected-only. Generate a selected-row preview first."));
        }

        try
        {
            var result = await _metadataMigrationRepository.AcceptApplyPreviewAsync(
                runGuid,
                request.ApplySelectedOnly,
                request.ExpectedPreviewFingerprint ?? string.Empty,
                request.TargetServerName ?? string.Empty,
                request.TargetDatabaseName ?? string.Empty,
                context.CancellationToken).ConfigureAwait(false);

            return new MetadataMigrationApplyPreviewAcceptResponse
            {
                IsAccepted = result.IsAccepted,
                ApplySelectedOnly = result.ApplySelectedOnly,
                PreviewFingerprint = result.PreviewFingerprint,
                ApplyCount = result.ApplyCount,
                AcceptedOnUtc = result.AcceptedOnUtc,
                AcceptedByUserId = result.AcceptedByUserId,
                Message = result.Message
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata apply preview acceptance SQL failed: {ex.Message}"));
        }
        catch (Concursus.EF.MetadataMigrationRepository.MetadataMigrationDriftException ex)
        {
            throw new RpcException(new Status(StatusCode.FailedPrecondition, ex.Message));
        }
        catch (Exception ex) when (ex is ArgumentException or InvalidOperationException)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, ex.Message));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            var message = ex.InnerException is null
                ? ex.Message
                : $"{ex.Message} Inner: {ex.InnerException.Message}";

            throw new RpcException(new Status(StatusCode.Internal, $"Metadata apply preview acceptance failed: {message}"));
        }
    }

    public override async Task<MetadataMigrationSelectionResponse> MetadataMigrationSelectionClear(
        MetadataMigrationSelectionClearRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenTargetSqlFromSelectionClearRequestAsync(request, context.CancellationToken);
            await using var cmd = new SqlCommand("SMigration.MetadataRunSelection_Clear", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = request.SchemaName ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = request.TableName ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@DifferenceType", SqlDbType.NVarChar, 30) { Value = request.DifferenceType ?? string.Empty });

            await cmd.ExecuteNonQueryAsync(context.CancellationToken);
            var selectedCount = await CountSelectedRowsAsync(cn, runGuid, context.CancellationToken);

            return new MetadataMigrationSelectionResponse
            {
                SelectedCount = selectedCount,
                Message = selectedCount == 0
                    ? "Metadata migration selection cleared."
                    : $"Metadata migration selection cleared. {selectedCount} selected record(s) remain."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata selection clear SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationSelectionResponse> MetadataMigrationSelectionUpsert(
        MetadataMigrationSelectionUpsertRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenTargetSqlFromSelectionUpsertRequestAsync(request, context.CancellationToken);
            await using var txBase = await cn.BeginTransactionAsync(context.CancellationToken);
            var tx = (SqlTransaction)txBase;
            var autoSelectedCount = 0;

            try
            {
                foreach (var item in request.Items)
                {
                    var sourceRowGuid = ParseGuid(item.SourceRowGuid, "sourceRowGuid");

                    await using var cmd = new SqlCommand("SMigration.MetadataRunSelection_Upsert", cn, tx)
                    {
                        CommandType = CommandType.StoredProcedure,
                        CommandTimeout = 300
                    };

                    cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
                    cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = item.SchemaName ?? string.Empty });
                    cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = item.TableName ?? string.Empty });
                    cmd.Parameters.Add(new SqlParameter("@SourceRowGuid", SqlDbType.UniqueIdentifier) { Value = sourceRowGuid });
                    cmd.Parameters.Add(new SqlParameter("@DifferenceType", SqlDbType.NVarChar, 30) { Value = item.DifferenceType ?? string.Empty });
                    cmd.Parameters.Add(new SqlParameter("@IsSelected", SqlDbType.Bit) { Value = item.IsSelected });

                    await cmd.ExecuteNonQueryAsync(context.CancellationToken);
                }

                // CYB-564: also select the related rows (dependants below, new parents above) once
                // for the whole save, so a new child cannot be applied without its new parent.
                var seeds = request.Items
                    .Where(item => item.IsSelected)
                    .Select(item => new
                    {
                        SchemaName = item.SchemaName ?? string.Empty,
                        TableName = item.TableName ?? string.Empty,
                        SourceRowGuid = ParseGuid(item.SourceRowGuid, "sourceRowGuid")
                    })
                    .ToList();

                if (seeds.Count > 0)
                {
                    await using var dependencyCmd = new SqlCommand("SMigration.MetadataRunSelection_AddDependencies", cn, tx)
                    {
                        CommandType = CommandType.StoredProcedure,
                        CommandTimeout = 300
                    };

                    dependencyCmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
                    dependencyCmd.Parameters.Add(new SqlParameter("@SeedJson", SqlDbType.NVarChar, -1) { Value = JsonSerializer.Serialize(seeds) });

                    autoSelectedCount = Convert.ToInt32(await dependencyCmd.ExecuteScalarAsync(context.CancellationToken) ?? 0);
                }

                await tx.CommitAsync(context.CancellationToken);
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
                    await tx.RollbackAsync(context.CancellationToken);
                }
                catch
                {
                }

                throw;
            }

            var selectedCount = await CountSelectedRowsAsync(cn, runGuid, context.CancellationToken);

            return new MetadataMigrationSelectionResponse
            {
                SelectedCount = selectedCount,
                AutoSelectedCount = autoSelectedCount,
                Message = autoSelectedCount == 0
                    ? $"Metadata migration selection saved. {selectedCount} selected record(s)."
                    : $"Metadata migration selection saved. {selectedCount} selected record(s), including {autoSelectedCount} related record(s) selected automatically."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata selection SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationIgnoreResponse> MetadataMigrationIgnoreUpsert(
        MetadataMigrationIgnoreUpsertRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        var sourceRowGuid = ParseGuid(request.SourceRowGuid, "sourceRowGuid");

        try
        {
            await using var cn = await OpenTargetSqlFromIgnoreUpsertRequestAsync(request, context.CancellationToken);
            await using var cmd = new SqlCommand("SMigration.MetadataIgnoredRecord_Upsert", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = request.SchemaName ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = request.TableName ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@SourceRowGuid", SqlDbType.UniqueIdentifier) { Value = sourceRowGuid });
            cmd.Parameters.Add(new SqlParameter("@Reason", SqlDbType.NVarChar, 500) { Value = request.Reason ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@IsIgnored", SqlDbType.Bit) { Value = request.IsIgnored });

            await cmd.ExecuteNonQueryAsync(context.CancellationToken);
            var ignoredCount = await CountIgnoredRowsAsync(cn, runGuid, context.CancellationToken);

            return new MetadataMigrationIgnoreResponse
            {
                IgnoredCount = ignoredCount,
                Message = request.IsIgnored
                    ? $"Metadata record ignored. {ignoredCount} ignored record(s) for this run scope."
                    : $"Metadata record unignored. {ignoredCount} ignored record(s) for this run scope."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata ignore SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationIgnoredRecordsResponse> MetadataMigrationIgnoredRecords(
        MetadataMigrationIgnoredRecordsRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        var response = new MetadataMigrationIgnoredRecordsResponse();

        try
        {
            await using var cn = await OpenTargetSqlFromIgnoredRecordsRequestAsync(request, context.CancellationToken);
            if (!await IgnoreTableExistsAsync(cn, context.CancellationToken))
            {
                return response;
            }

            await using var cmd = new SqlCommand("SMigration.MetadataIgnoredRecords_List", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            cmd.Parameters.Add(new SqlParameter("@IncludeInactive", SqlDbType.Bit) { Value = request.IncludeInactive });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                var record = new MetadataMigrationIgnoredRecord
                {
                    Guid = Convert.ToString(reader["Guid"]) ?? string.Empty,
                    DatabaseName = Convert.ToString(reader["DatabaseName"]) ?? string.Empty,
                    SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                    TableName = Convert.ToString(reader["TableName"]) ?? string.Empty,
                    SourceRowGuid = Convert.ToString(reader["SourceRowGuid"]) ?? string.Empty,
                    StableRecordKey = Convert.ToString(reader["StableRecordKey"]) ?? string.Empty,
                    Reason = Convert.ToString(reader["Reason"]) ?? string.Empty,
                    IgnoredByUserId = reader["IgnoredByUserId"] == DBNull.Value ? -1 : Convert.ToInt32(reader["IgnoredByUserId"]),
                    IgnoredOnUtc = Convert.ToString(reader["IgnoredOnUtc"]) ?? string.Empty,
                    UnignoredOnUtc = Convert.ToString(reader["UnignoredOnUtc"]) ?? string.Empty,
                    RowStatus = reader["RowStatus"] == DBNull.Value ? 0 : Convert.ToInt32(reader["RowStatus"])
                };

                response.Records.Add(record);
            }

            response.IgnoredCount = response.Records.Count(x => x.RowStatus != 0 && x.RowStatus != 254);
            return response;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata ignored records SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationEntityTypeScopeResponse> MetadataMigrationEntityTypeScopeList(
        MetadataMigrationEntityTypeScopeRequest request,
        ServerCallContext context)
    {
        var response = new MetadataMigrationEntityTypeScopeResponse();

        try
        {
            await using var cn = await OpenTargetSqlFromEntityTypeScopeRequestAsync(request, context.CancellationToken);
            await using var cmd = new SqlCommand("SMigration.MetadataEntityTypeScope_List", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@ShowMetadataOnly", SqlDbType.Bit) { Value = request.ShowMetadataOnly });
            cmd.Parameters.Add(new SqlParameter("@SearchText", SqlDbType.NVarChar, 250) { Value = request.SearchText ?? string.Empty });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.Rows.Add(new MetadataMigrationEntityTypeScopeRow
                {
                    EntityTypeGuid = Convert.ToString(reader["EntityTypeGuid"]) ?? string.Empty,
                    Name = Convert.ToString(reader["Name"]) ?? string.Empty,
                    RowStatus = reader["RowStatus"] == DBNull.Value ? 0 : Convert.ToInt32(reader["RowStatus"]),
                    IsMetaData = reader["IsMetaData"] != DBNull.Value && Convert.ToBoolean(reader["IsMetaData"]),
                    HasDocuments = reader["HasDocuments"] != DBNull.Value && Convert.ToBoolean(reader["HasDocuments"]),
                    IsRootEntity = reader["IsRootEntity"] != DBNull.Value && Convert.ToBoolean(reader["IsRootEntity"]),
                    IsDeletable = reader["IsDeletable"] != DBNull.Value && Convert.ToBoolean(reader["IsDeletable"]),
                    HasMainHoBT = reader["HasMainHoBT"] != DBNull.Value && Convert.ToBoolean(reader["HasMainHoBT"]),
                    MainHoBTSchemaName = Convert.ToString(reader["MainHoBTSchemaName"]) ?? string.Empty,
                    MainHoBTObjectName = Convert.ToString(reader["MainHoBTObjectName"]) ?? string.Empty
                });
            }

            return response;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata EntityType scope list SQL failed: {ex.Message}"));
        }
        catch (Exception ex)
        {
            var message = ex.InnerException is null
                ? ex.Message
                : $"{ex.Message} Inner: {ex.InnerException.Message}";

            throw new RpcException(new Status(StatusCode.Internal, $"Metadata EntityType scope list failed: {message}"));
        }
    }

    public override async Task<MetadataMigrationEntityTypeScopeSaveResponse> MetadataMigrationEntityTypeScopeSave(
        MetadataMigrationEntityTypeScopeSaveRequest request,
        ServerCallContext context)
    {
        try
        {
            await using var cn = await OpenTargetSqlFromEntityTypeScopeSaveRequestAsync(request, context.CancellationToken);
            await using var txBase = await cn.BeginTransactionAsync(context.CancellationToken);
            var tx = (SqlTransaction)txBase;
            var updatedCount = 0;

            try
            {
                foreach (var item in request.Items)
                {
                    var entityTypeGuid = ParseGuid(item.EntityTypeGuid, "entityTypeGuid");

                    await using var cmd = new SqlCommand("SMigration.MetadataEntityTypeScope_Set", cn, tx)
                    {
                        CommandType = CommandType.StoredProcedure,
                        CommandTimeout = 300
                    };

                    cmd.Parameters.Add(new SqlParameter("@EntityTypeGuid", SqlDbType.UniqueIdentifier) { Value = entityTypeGuid });
                    cmd.Parameters.Add(new SqlParameter("@IsMetaData", SqlDbType.Bit) { Value = item.IsMetaData });

                    var value = await cmd.ExecuteScalarAsync(context.CancellationToken);
                    if (value != null && value != DBNull.Value)
                    {
                        updatedCount += Convert.ToInt32(value);
                    }
                }

                await tx.CommitAsync(context.CancellationToken);
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
                    await tx.RollbackAsync(context.CancellationToken);
                }
                catch
                {
                }

                throw;
            }

            return new MetadataMigrationEntityTypeScopeSaveResponse
            {
                UpdatedCount = updatedCount,
                Message = updatedCount == 1
                    ? "1 EntityType metadata scope change saved."
                    : $"{updatedCount} EntityType metadata scope changes saved."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata EntityType scope save SQL failed: {ex.Message}"));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            var message = ex.InnerException is null
                ? ex.Message
                : $"{ex.Message} Inner: {ex.InnerException.Message}";

            throw new RpcException(new Status(StatusCode.Internal, $"Metadata EntityType scope save failed: {message}"));
        }
    }

    public override async Task<MetadataMigrationDashboardResponse> MetadataMigrationDashboard(
        MetadataMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenTargetSqlFromRequestAsync(request, context.CancellationToken);

            var validation = await ReadValidationAsync(cn, runGuid, context.CancellationToken);
            var identityMap = await ReadIdentityMapAsync(cn, runGuid, context.CancellationToken);
            var stagedCounts = await ReadStagedCountsAsync(cn, runGuid, context.CancellationToken);
            var executionLog = await ReadExecutionLogAsync(cn, runGuid, context.CancellationToken);
            var selectedCount = await CountSelectedRowsAsync(cn, runGuid, context.CancellationToken);
            var ignoredCount = await CountIgnoredRowsAsync(cn, runGuid, context.CancellationToken);

            var response = new MetadataMigrationDashboardResponse
            {
                Run = await ReadRunSummaryAsync(cn, runGuid, context.CancellationToken),
                FailCount = validation.FailCount,
                WarnCount = validation.WarnCount,
                InfoCount = validation.InfoCount,
                InsertCount = stagedCounts.Where(x => x.DifferenceType == "Insert").Sum(x => x.Count),
                UpdateCount = stagedCounts.Where(x => x.DifferenceType == "Update").Sum(x => x.Count),
                NoChangeCount = stagedCounts.Where(x => x.DifferenceType == "NoChange").Sum(x => x.Count),
                MapRows = identityMap.Sum(x => x.MapRows),
                MissingTargetRows = identityMap.Sum(x => x.MissingTargetRows),
                SelectedCount = selectedCount,
                IgnoredCount = ignoredCount
            };

            response.ValidationIssues.AddRange(validation.ValidationIssues);
            response.IdentityMap.AddRange(identityMap);
            response.StagedCounts.AddRange(stagedCounts);
            response.ExecutionLog.AddRange(executionLog);

            return response;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata dashboard SQL failed: {ex.Message}"));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            var message = ex.InnerException is null
                ? ex.Message
                : $"{ex.Message} Inner: {ex.InnerException.Message}";

            throw new RpcException(new Status(StatusCode.Internal, $"Metadata dashboard failed: {message}"));
        }
    }

    public override async Task<MetadataMigrationStagedRowsResponse> MetadataMigrationStagedRows(
        MetadataMigrationRowsRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");
        var response = new MetadataMigrationStagedRowsResponse();

        try
        {
            await using var cn = await OpenTargetSqlFromRowsRequestAsync(request, context.CancellationToken);
            var hasSelectionTable = await SelectionTableExistsAsync(cn, context.CancellationToken);
            var hasIgnoreTable = await IgnoreTableExistsAsync(cn, context.CancellationToken);

            var selectionJoin = hasSelectionTable
                ? @"
            LEFT JOIN SMigration.Metadata_RunSelections AS sel
                ON sel.RunGuid = sr.RunGuid
               AND sel.RegistryGuid = sr.RegistryGuid
               AND sel.SourceRowGuid = sr.SourceRowGuid
               AND sel.RowStatus NOT IN (0,254)"
                : string.Empty;

            var ignoreJoin = hasIgnoreTable
                ? @"
            LEFT JOIN SMigration.Metadata_IgnoredRecords AS ign
                ON ign.DatabaseName = r.TargetDatabaseName
               AND ign.RegistryGuid = sr.RegistryGuid
               AND ign.SourceRowGuid = sr.SourceRowGuid
               AND ign.RowStatus NOT IN (0,254)"
                : string.Empty;

            var sql = $@"
            SELECT TOP (500)
                tr.SchemaName,
                tr.TableName,
                sr.SourceRowGuid,
                sr.SourceRowId,
                sr.DifferenceType,
                sr.SourcePayloadJson,
                sr.TargetPayloadJson,
                CONVERT(bit, {(hasSelectionTable ? "CASE WHEN sel.ID IS NULL THEN 0 ELSE 1 END" : "0")}) AS IsSelected,
                CONVERT(bit, {(hasIgnoreTable ? "CASE WHEN ign.ID IS NULL THEN 0 ELSE 1 END" : "0")}) AS IsIgnored,
                {(hasIgnoreTable ? "ISNULL(ign.Reason, N'')" : "CONVERT(nvarchar(500), N'')")} AS IgnoreReason,
                {(hasIgnoreTable ? "CONVERT(nvarchar(30), ign.IgnoredOnUtc, 126)" : "CONVERT(nvarchar(30), N'')")} AS IgnoredOnUtc,
                {(hasSelectionTable ? "ISNULL(sel.SelectionSource, N'')" : "CONVERT(nvarchar(30), N'')")} AS SelectionSource
            FROM SMigration.Metadata_StagedRows AS sr
            INNER JOIN SMigration.Metadata_TableRegistry AS tr
                ON tr.Guid = sr.RegistryGuid
               AND tr.RowStatus NOT IN (0,254)
            INNER JOIN SMigration.Metadata_Run AS r
                ON r.Guid = sr.RunGuid
               AND r.RowStatus NOT IN (0,254){selectionJoin}{ignoreJoin}
            WHERE sr.RunGuid = @RunGuid
              AND sr.RowStatus NOT IN (0,254)
              AND (@SchemaName = N'' OR tr.SchemaName = @SchemaName)
              AND (@TableName = N'' OR tr.TableName = @TableName)
              AND (@DifferenceType = N'' OR sr.DifferenceType = @DifferenceType)
              AND (@IncludeIgnored = 1 OR {(hasIgnoreTable ? "ign.ID IS NULL" : "1 = 1")})
            ORDER BY tr.SchemaName, tr.TableName, sr.SourceRowId;";

            await using var cmd = new SqlCommand(sql, cn)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 300
            };

            AddRowsFilterParameters(cmd, runGuid, request.SchemaName, request.TableName, request.DifferenceType);
            cmd.Parameters.Add(new SqlParameter("@IncludeIgnored", SqlDbType.Bit) { Value = request.IncludeIgnored });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                var row = new MetadataMigrationStagedRow
                {
                    SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                    TableName = Convert.ToString(reader["TableName"]) ?? string.Empty,
                    SourceRowGuid = Convert.ToString(reader["SourceRowGuid"]) ?? string.Empty,
                    SourceRowId = reader["SourceRowId"] == DBNull.Value ? 0 : Convert.ToInt64(reader["SourceRowId"]),
                    DifferenceType = Convert.ToString(reader["DifferenceType"]) ?? string.Empty,
                    SourcePayloadJson = Convert.ToString(reader["SourcePayloadJson"]) ?? "{}",
                    TargetPayloadJson = Convert.ToString(reader["TargetPayloadJson"]) ?? "{}",
                    IsSelected = reader["IsSelected"] != DBNull.Value && Convert.ToBoolean(reader["IsSelected"]),
                    IsIgnored = reader["IsIgnored"] != DBNull.Value && Convert.ToBoolean(reader["IsIgnored"]),
                    IgnoreReason = Convert.ToString(reader["IgnoreReason"]) ?? string.Empty,
                    IgnoredOnUtc = Convert.ToString(reader["IgnoredOnUtc"]) ?? string.Empty,
                    SelectionSource = Convert.ToString(reader["SelectionSource"]) ?? string.Empty
                };

                CopyDictionary(ParseJsonDictionary(row.SourcePayloadJson), row.SourceValues);
                CopyDictionary(ParseJsonDictionary(row.TargetPayloadJson), row.TargetValues);
                response.Rows.Add(row);
            }

            return response;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata staged rows SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationDiffResponse> MetadataMigrationDiff(
        MetadataMigrationRowsRequest request,
        ServerCallContext context)
    {
        var staged = await MetadataMigrationStagedRows(request, context);
        var response = new MetadataMigrationDiffResponse();

        foreach (var stagedRow in staged.Rows)
        {
            var diff = new MetadataMigrationDiffRow
            {
                SchemaName = stagedRow.SchemaName,
                TableName = stagedRow.TableName,
                SourceRowGuid = stagedRow.SourceRowGuid,
                DifferenceType = stagedRow.DifferenceType,
                IsSelected = stagedRow.IsSelected,
                IsIgnored = stagedRow.IsIgnored,
                IgnoreReason = stagedRow.IgnoreReason,
                IgnoredOnUtc = stagedRow.IgnoredOnUtc,
                SelectionSource = stagedRow.SelectionSource
            };

            foreach (var kvp in stagedRow.SourceValues)
            {
                diff.SourceValues.Add(kvp.Key, kvp.Value);
            }

            foreach (var kvp in stagedRow.TargetValues)
            {
                diff.TargetValues.Add(kvp.Key, kvp.Value);
            }

            foreach (var key in stagedRow.SourceValues.Keys.Union(stagedRow.TargetValues.Keys).OrderBy(x => x))
            {
                stagedRow.SourceValues.TryGetValue(key, out var sourceValue);
                stagedRow.TargetValues.TryGetValue(key, out var targetValue);
                if (!StringComparer.Ordinal.Equals(sourceValue ?? string.Empty, targetValue ?? string.Empty))
                {
                    diff.DifferingColumns.Add(key);
                }
            }

            response.Rows.Add(diff);
        }

        return response;
    }

    // Null (rather than an empty-string placeholder) whenever any key column is missing or
    // empty, so such rows never spuriously match one another - mirroring how the same-server
    // SQL path's equality-based JOIN never matches on a NULL column value either.
    private static string? BuildNaturalKey(Dictionary<string, string> values, IReadOnlyList<string> columnNames)
    {
        var parts = new List<string>(columnNames.Count);
        foreach (var columnName in columnNames)
        {
            if (!values.TryGetValue(columnName, out var value) || string.IsNullOrEmpty(value))
            {
                return null;
            }

            parts.Add(value);
        }

        return string.Join("", parts);
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
        await cn.OpenAsync(cancellationToken);
        return cn;
    }

    private static bool IsSameSqlServer(string? sourceServerName, string? targetServerName)
    {
        static string Normalize(string? value) =>
            (value ?? string.Empty)
                .Trim()
                .Replace("/", "\\", StringComparison.Ordinal)
                .ToUpperInvariant();

        var source = Normalize(sourceServerName);
        var target = Normalize(targetServerName);

        if (string.IsNullOrWhiteSpace(source) || string.IsNullOrWhiteSpace(target))
        {
            return false;
        }

        return string.Equals(source, target, StringComparison.Ordinal);
    }

    private async Task<SqlConnection> OpenTargetSqlFromRequestAsync(
        MetadataMigrationRunRequest request,
        CancellationToken cancellationToken)
    {
        await using var templateConnection = await OpenSqlAsync(cancellationToken);
        return await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            request.TargetServerName,
            request.TargetDatabaseName,
            cancellationToken);
    }

    private async Task<SqlConnection> OpenTargetSqlFromRowsRequestAsync(
        MetadataMigrationRowsRequest request,
        CancellationToken cancellationToken)
    {
        await using var templateConnection = await OpenSqlAsync(cancellationToken);
        return await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            request.TargetServerName,
            request.TargetDatabaseName,
            cancellationToken);
    }
    private async Task<SqlConnection> OpenTargetSqlFromSelectionClearRequestAsync(
        MetadataMigrationSelectionClearRequest request,
        CancellationToken cancellationToken)
    {
        await using var templateConnection = await OpenSqlAsync(cancellationToken);
        return await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            request.TargetServerName,
            request.TargetDatabaseName,
            cancellationToken);
    }

    private async Task<SqlConnection> OpenTargetSqlFromSelectionUpsertRequestAsync(
        MetadataMigrationSelectionUpsertRequest request,
        CancellationToken cancellationToken)
    {
        await using var templateConnection = await OpenSqlAsync(cancellationToken);
        return await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            request.TargetServerName,
            request.TargetDatabaseName,
            cancellationToken);
    }

    private async Task<SqlConnection> OpenTargetSqlFromIgnoreUpsertRequestAsync(
        MetadataMigrationIgnoreUpsertRequest request,
        CancellationToken cancellationToken)
    {
        await using var templateConnection = await OpenSqlAsync(cancellationToken);
        return await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            request.TargetServerName,
            request.TargetDatabaseName,
            cancellationToken);
    }

    private async Task<SqlConnection> OpenTargetSqlFromIgnoredRecordsRequestAsync(
        MetadataMigrationIgnoredRecordsRequest request,
        CancellationToken cancellationToken)
    {
        await using var templateConnection = await OpenSqlAsync(cancellationToken);
        return await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            request.TargetServerName,
            request.TargetDatabaseName,
            cancellationToken);
    }

    private async Task<SqlConnection> OpenTargetSqlFromEntityTypeScopeRequestAsync(
        MetadataMigrationEntityTypeScopeRequest request,
        CancellationToken cancellationToken)
    {
        await using var templateConnection = await OpenSqlAsync(cancellationToken);
        return await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            request.ServerName,
            request.DatabaseName,
            cancellationToken);
    }

    private async Task<SqlConnection> OpenTargetSqlFromEntityTypeScopeSaveRequestAsync(
        MetadataMigrationEntityTypeScopeSaveRequest request,
        CancellationToken cancellationToken)
    {
        await using var templateConnection = await OpenSqlAsync(cancellationToken);
        return await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            request.ServerName,
            request.DatabaseName,
            cancellationToken);
    }

    private static Guid ParseGuid(string value, string parameterName)
    {
        if (!Guid.TryParse(value, out var guid))
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Invalid {parameterName}."));
        }

        return guid;
    }

    private static async Task ExecuteRunProcedureAsync(SqlConnection cn, string procedureName, Guid runGuid, CancellationToken cancellationToken, bool skipRegistrySync = false, bool includeRetirements = false)
    {
        await using var cmd = new SqlCommand(procedureName, cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 600
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        if (skipRegistrySync)
        {
            cmd.Parameters.Add(new SqlParameter("@SkipRegistrySync", SqlDbType.Bit) { Value = true });
        }
        if (includeRetirements)
        {
            cmd.Parameters.Add(new SqlParameter("@IncludeRetirements", SqlDbType.Bit) { Value = true });
        }

        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static void AddRowsFilterParameters(SqlCommand cmd, Guid runGuid, string schemaName, string tableName, string differenceType)
    {
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = schemaName ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = tableName ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@DifferenceType", SqlDbType.NVarChar, 30) { Value = differenceType ?? string.Empty });
    }

    private static async Task<MetadataMigrationRunSummary> ReadRunSummaryAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
SELECT
    r.Guid,
    r.SourceEnvironment,
    r.TargetEnvironment,
    r.SourceServerName,
    r.SourceDatabaseName,
    r.TargetServerName,
    r.TargetDatabaseName,
    r.RunStatus,
    r.IsValidateOnly,
    r.CreatedOnUtc,
    r.ValidatedOnUtc,
    r.AppliedOnUtc,
    r.SummaryJson
FROM SMigration.Metadata_Run AS r
WHERE r.Guid = @RunGuid
  AND r.RowStatus NOT IN (0,254);", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new RpcException(new Status(StatusCode.NotFound, "Metadata run was not found."));
        }

        return MapRunSummary(reader);
    }

    private static MetadataMigrationRunSummary MapRunSummary(SqlDataReader reader) => new()
    {
        RunGuid = Convert.ToString(reader["Guid"]) ?? string.Empty,
        SourceEnvironment = Convert.ToString(reader["SourceEnvironment"]) ?? string.Empty,
        TargetEnvironment = Convert.ToString(reader["TargetEnvironment"]) ?? string.Empty,
        SourceServerName = Convert.ToString(reader["SourceServerName"]) ?? string.Empty,
        SourceDatabaseName = Convert.ToString(reader["SourceDatabaseName"]) ?? string.Empty,
        TargetServerName = Convert.ToString(reader["TargetServerName"]) ?? string.Empty,
        TargetDatabaseName = Convert.ToString(reader["TargetDatabaseName"]) ?? string.Empty,
        RunStatus = Convert.ToString(reader["RunStatus"]) ?? string.Empty,
        IsValidateOnly = Convert.ToBoolean(reader["IsValidateOnly"]),
        CreatedOnUtc = Convert.ToString(reader["CreatedOnUtc"]) ?? string.Empty,
        ValidatedOnUtc = Convert.ToString(reader["ValidatedOnUtc"]) ?? string.Empty,
        AppliedOnUtc = Convert.ToString(reader["AppliedOnUtc"]) ?? string.Empty,
        SummaryJson = Convert.ToString(reader["SummaryJson"]) ?? string.Empty
    };

    private static async Task<RepeatedField<MetadataMigrationTableCount>> ReadStagedCountsAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        var rows = new RepeatedField<MetadataMigrationTableCount>();
        var hasIgnoreTable = await IgnoreTableExistsAsync(cn, cancellationToken);

        var ignoreJoin = hasIgnoreTable
            ? @"
            INNER JOIN SMigration.Metadata_Run AS r
                ON r.Guid = sr.RunGuid
               AND r.RowStatus NOT IN (0,254)
            LEFT JOIN SMigration.Metadata_IgnoredRecords AS ign
                ON ign.DatabaseName = r.TargetDatabaseName
               AND ign.RegistryGuid = sr.RegistryGuid
               AND ign.SourceRowGuid = sr.SourceRowGuid
               AND ign.RowStatus NOT IN (0,254)"
            : string.Empty;

        var ignoreFilter = hasIgnoreTable
            ? " AND ign.ID IS NULL"
            : string.Empty;

        var sql = $@"
            SELECT
                tr.SchemaName,
                tr.TableName,
                sr.DifferenceType,
                COUNT_BIG(1) AS [RowCount]
            FROM SMigration.Metadata_StagedRows AS sr
            INNER JOIN SMigration.Metadata_TableRegistry AS tr
                ON tr.Guid = sr.RegistryGuid
               AND tr.RowStatus NOT IN (0,254){ignoreJoin}
            WHERE sr.RunGuid = @RunGuid
              AND sr.RowStatus NOT IN (0,254){ignoreFilter}
            GROUP BY tr.SchemaName, tr.TableName, sr.DifferenceType
            ORDER BY tr.SchemaName, tr.TableName, sr.DifferenceType;";

        await using var cmd = new SqlCommand(sql, cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            rows.Add(new MetadataMigrationTableCount
            {
                SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                TableName = Convert.ToString(reader["TableName"]) ?? string.Empty,
                DifferenceType = Convert.ToString(reader["DifferenceType"]) ?? string.Empty,
                Count = Convert.ToInt32(reader["RowCount"])
            });
        }
        return rows;
    }

    private static async Task<bool> SelectionTableExistsAsync(SqlConnection cn, CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
SELECT
    CONVERT(bit, CASE WHEN OBJECT_ID(N'SMigration.Metadata_RunSelections', N'U') IS NULL THEN 0 ELSE 1 END) AS TableExists;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 30
        };

        var value = await cmd.ExecuteScalarAsync(cancellationToken);
        return value != null && value != DBNull.Value && Convert.ToBoolean(value);
    }

    private static async Task<bool> IgnoreTableExistsAsync(SqlConnection cn, CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
SELECT
    CONVERT(bit, CASE WHEN OBJECT_ID(N'SMigration.Metadata_IgnoredRecords', N'U') IS NULL THEN 0 ELSE 1 END) AS TableExists;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 30
        };

        var value = await cmd.ExecuteScalarAsync(cancellationToken);
        return value != null && value != DBNull.Value && Convert.ToBoolean(value);
    }

    private static async Task<int> CountSelectedRowsAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        if (!await SelectionTableExistsAsync(cn, cancellationToken))
        {
            return 0;
        }

        var hasIgnoreTable = await IgnoreTableExistsAsync(cn, cancellationToken);
        var sql = hasIgnoreTable
            ? @"
SELECT
    COUNT_BIG(1) AS SelectedCount
FROM SMigration.Metadata_RunSelections AS sel
INNER JOIN SMigration.Metadata_StagedRows AS sr
    ON sr.RunGuid = sel.RunGuid
   AND sr.RegistryGuid = sel.RegistryGuid
   AND sr.SourceRowGuid = sel.SourceRowGuid
   AND sr.RowStatus NOT IN (0,254)
INNER JOIN SMigration.Metadata_Run AS r
    ON r.Guid = sr.RunGuid
   AND r.RowStatus NOT IN (0,254)
LEFT JOIN SMigration.Metadata_IgnoredRecords AS ign
    ON ign.DatabaseName = r.TargetDatabaseName
   AND ign.RegistryGuid = sr.RegistryGuid
   AND ign.SourceRowGuid = sr.SourceRowGuid
   AND ign.RowStatus NOT IN (0,254)
WHERE sel.RunGuid = @RunGuid
  AND sel.RowStatus NOT IN (0,254)
  AND sr.DifferenceType IN (N'Insert', N'Update')
  AND ign.ID IS NULL;"
            : @"
SELECT
    COUNT_BIG(1) AS SelectedCount
FROM SMigration.Metadata_RunSelections AS sel
INNER JOIN SMigration.Metadata_StagedRows AS sr
    ON sr.RunGuid = sel.RunGuid
   AND sr.RegistryGuid = sel.RegistryGuid
   AND sr.SourceRowGuid = sel.SourceRowGuid
   AND sr.RowStatus NOT IN (0,254)
WHERE sel.RunGuid = @RunGuid
  AND sel.RowStatus NOT IN (0,254)
  AND sr.DifferenceType IN (N'Insert', N'Update');";

        await using var cmd = new SqlCommand(sql, cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        var value = await cmd.ExecuteScalarAsync(cancellationToken);
        return value == null || value == DBNull.Value ? 0 : Convert.ToInt32(value);
    }

    private static async Task<int> CountIgnoredRowsAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        if (!await IgnoreTableExistsAsync(cn, cancellationToken))
        {
            return 0;
        }

        await using var cmd = new SqlCommand(@"
SELECT
    COUNT_BIG(1) AS IgnoredCount
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN SMigration.Metadata_Run AS r
    ON r.Guid = sr.RunGuid
   AND r.RowStatus NOT IN (0,254)
INNER JOIN SMigration.Metadata_IgnoredRecords AS ign
    ON ign.DatabaseName = r.TargetDatabaseName
   AND ign.RegistryGuid = sr.RegistryGuid
   AND ign.SourceRowGuid = sr.SourceRowGuid
   AND ign.RowStatus NOT IN (0,254)
WHERE sr.RunGuid = @RunGuid
  AND sr.RowStatus NOT IN (0,254);", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        var value = await cmd.ExecuteScalarAsync(cancellationToken);
        return value == null || value == DBNull.Value ? 0 : Convert.ToInt32(value);
    }

    private static async Task<MetadataMigrationValidateResponse> ReadValidationAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        var response = new MetadataMigrationValidateResponse();
        var hasIgnoreTable = await IgnoreTableExistsAsync(cn, cancellationToken);

        var ignoreJoin = hasIgnoreTable
            ? @"
LEFT JOIN SMigration.Metadata_Run AS r
    ON r.Guid = vi.RunGuid
   AND r.RowStatus NOT IN (0,254)
LEFT JOIN SMigration.Metadata_IgnoredRecords AS ign
    ON ign.DatabaseName = r.TargetDatabaseName
   AND ign.RegistryGuid = vi.RegistryGuid
   AND ign.SourceRowGuid = vi.SourceRowGuid
   AND ign.RowStatus NOT IN (0,254)"
            : string.Empty;

        var ignoreFilter = hasIgnoreTable
            ? " AND ign.ID IS NULL"
            : string.Empty;

        var selectedScopeIgnoreJoin = hasIgnoreTable
            ? @"
LEFT JOIN SMigration.Metadata_IgnoredRecords AS selectedIgnored
    ON selectedIgnored.DatabaseName = selectedRun.TargetDatabaseName
   AND selectedIgnored.RegistryGuid = selectedRow.RegistryGuid
   AND selectedIgnored.SourceRowGuid = selectedRow.SourceRowGuid
   AND selectedIgnored.RowStatus NOT IN (0,254)"
            : string.Empty;

        var selectedScopeIgnoreFilter = hasIgnoreTable
            ? " AND selectedIgnored.ID IS NULL"
            : string.Empty;

        var sql = $@"
SELECT
    vi.Guid,
    vi.RegistryGuid,
    vi.SourceRowGuid,
    ISNULL(tr.SchemaName, N'') AS SchemaName,
    ISNULL(tr.TableName, N'') AS TableName,
    vi.Severity,
    vi.IssueCode,
    vi.IssueMessage,
    vi.DetailsJson,
    CONVERT
    (
        bit,
        CASE
            WHEN vi.IssueCode IN (N'DuplicateSourceGuid', N'DuplicateTargetGuid', N'DuplicateTargetKey', N'UnresolvedReference')
             AND vi.RegistryGuid IS NOT NULL
             AND vi.SourceRowGuid IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS CanIgnore,
    CONVERT(bit, CASE WHEN ignoredIssue.ID IS NULL THEN 0 ELSE 1 END) AS IsIgnored,
    ISNULL(ignoredIssue.Reason, N'') AS IgnoreReason,
    CONVERT(NVARCHAR(30), ignoredIssue.IgnoredOnUtc, 126) AS IgnoredOnUtc,
    ISNULL(ignoredIssue.IgnoredByUserId, -1) AS IgnoredByUserId
FROM SMigration.Metadata_ValidationIssues AS vi
LEFT JOIN SMigration.Metadata_TableRegistry AS tr
    ON tr.Guid = vi.RegistryGuid
   AND tr.RowStatus NOT IN (0,254)
LEFT JOIN SMigration.Metadata_Run AS issueRun
    ON issueRun.Guid = vi.RunGuid
   AND issueRun.RowStatus NOT IN (0,254)
LEFT JOIN SMigration.Metadata_ValidationIssueIgnores AS ignoredIssue
    ON ignoredIssue.DatabaseName = issueRun.TargetDatabaseName
   AND ignoredIssue.RegistryGuid = vi.RegistryGuid
   AND ignoredIssue.SourceRowGuid = vi.SourceRowGuid
   AND ignoredIssue.IssueCode = vi.IssueCode
   AND ignoredIssue.RowStatus NOT IN (0,254){ignoreJoin}
WHERE vi.RunGuid = @RunGuid
  AND vi.RowStatus NOT IN (0,254){ignoreFilter}
  AND
  (
      vi.IssueCode IN (N'RunNotFound', N'NoSelectedRows', N'DuplicateSourceGuid')
      OR EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_RunSelections AS selected
          INNER JOIN SMigration.Metadata_StagedRows AS selectedRow
              ON selectedRow.RunGuid = selected.RunGuid
             AND selectedRow.RegistryGuid = selected.RegistryGuid
             AND selectedRow.SourceRowGuid = selected.SourceRowGuid
             AND selectedRow.RowStatus NOT IN (0,254)
          INNER JOIN SMigration.Metadata_Run AS selectedRun
              ON selectedRun.Guid = selected.RunGuid
             AND selectedRun.RowStatus NOT IN (0,254){selectedScopeIgnoreJoin}
          WHERE selected.RunGuid = vi.RunGuid
            AND selected.RowStatus NOT IN (0,254)
            AND selectedRow.DifferenceType IN (N'Insert', N'Update'){selectedScopeIgnoreFilter}
            AND selectedRow.RegistryGuid = vi.RegistryGuid
            AND (vi.SourceRowGuid IS NULL OR selectedRow.SourceRowGuid = vi.SourceRowGuid)
            AND NOT EXISTS
            (
                SELECT 1
                FROM SMigration.Metadata_IdentityMapOverrides AS selectedOverride
                WHERE selectedOverride.DatabaseName = selectedRun.TargetDatabaseName
                  AND selectedOverride.RegistryGuid = selectedRow.RegistryGuid
                  AND selectedOverride.SourceRowGuid = selectedRow.SourceRowGuid
                  AND selectedOverride.RowStatus NOT IN (0,254)
            )
      )
  )
ORDER BY IsIgnored, vi.Severity DESC, tr.SchemaName, tr.TableName, vi.IssueCode;";

        await using var cmd = new SqlCommand(sql, cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var severity = Convert.ToString(reader["Severity"]) ?? string.Empty;
            var isIgnored = reader["IsIgnored"] != DBNull.Value && Convert.ToBoolean(reader["IsIgnored"]);
            if (!isIgnored && severity.Equals("Fail", StringComparison.OrdinalIgnoreCase)) response.FailCount++;
            if (!isIgnored && severity.Equals("Warn", StringComparison.OrdinalIgnoreCase)) response.WarnCount++;
            if (!isIgnored && severity.Equals("Info", StringComparison.OrdinalIgnoreCase)) response.InfoCount++;

            response.ValidationIssues.Add(new MetadataMigrationValidationIssue
            {
                Guid = Convert.ToString(reader["Guid"]) ?? string.Empty,
                RegistryGuid = Convert.ToString(reader["RegistryGuid"]) ?? string.Empty,
                SourceRowGuid = Convert.ToString(reader["SourceRowGuid"]) ?? string.Empty,
                SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                TableName = Convert.ToString(reader["TableName"]) ?? string.Empty,
                Severity = severity,
                IssueCode = Convert.ToString(reader["IssueCode"]) ?? string.Empty,
                IssueMessage = Convert.ToString(reader["IssueMessage"]) ?? string.Empty,
                DetailsJson = Convert.ToString(reader["DetailsJson"]) ?? string.Empty,
                CanIgnore = reader["CanIgnore"] != DBNull.Value && Convert.ToBoolean(reader["CanIgnore"]),
                IsIgnored = isIgnored,
                IgnoreReason = Convert.ToString(reader["IgnoreReason"]) ?? string.Empty,
                IgnoredOnUtc = Convert.ToString(reader["IgnoredOnUtc"]) ?? string.Empty,
                IgnoredByUserId = reader["IgnoredByUserId"] == DBNull.Value ? -1 : Convert.ToInt32(reader["IgnoredByUserId"])
            });
        }
        return response;
    }

    private sealed class IdentityMapSourceContext
    {
        public MetadataRegistryRow Registry { get; init; } = new();
        public string SourcePayloadJson { get; init; } = "{}";
    }

    private static async Task<IdentityMapSourceContext> ReadIdentityMapSourceContextAsync(
        SqlConnection cn,
        Guid runGuid,
        string schemaName,
        string tableName,
        Guid sourceRowGuid,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
SELECT TOP (1)
    tr.Guid AS RegistryGuid,
    tr.SchemaName,
    tr.TableName,
    tr.GuidColumnName,
    tr.PrimaryKeyColumnName,
    ISNULL(sr.SourcePayloadJson, N'{}') AS SourcePayloadJson
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN SMigration.Metadata_TableRegistry AS tr
    ON tr.Guid = sr.RegistryGuid
   AND tr.RowStatus NOT IN (0,254)
WHERE sr.RunGuid = @RunGuid
  AND sr.RowStatus NOT IN (0,254)
  AND tr.SchemaName = @SchemaName
  AND tr.TableName = @TableName
  AND sr.SourceRowGuid = @SourceRowGuid;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = schemaName ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = tableName ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@SourceRowGuid", SqlDbType.UniqueIdentifier) { Value = sourceRowGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new RpcException(new Status(StatusCode.NotFound, "Metadata identity map source row was not found for candidate search."));
        }

        return new IdentityMapSourceContext
        {
            Registry = new MetadataRegistryRow
            {
                RegistryGuid = (Guid)reader["RegistryGuid"],
                SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                TableName = Convert.ToString(reader["TableName"]) ?? string.Empty,
                GuidColumnName = Convert.ToString(reader["GuidColumnName"]) ?? string.Empty,
                PrimaryKeyColumnName = Convert.ToString(reader["PrimaryKeyColumnName"]) ?? string.Empty
            },
            SourcePayloadJson = Convert.ToString(reader["SourcePayloadJson"]) ?? "{}"
        };
    }

    private static string GetMetadataDisplayValue(Dictionary<string, string> values, string fallback)
    {
        foreach (var key in new[] { "Name", "FullName", "Code", "Description", "Title", "SystemName" })
        {
            if (values.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value))
            {
                return value;
            }
        }

        return fallback;
    }

    private static int ScoreIdentityMapCandidate(
        Dictionary<string, string> sourceValues,
        Dictionary<string, string> targetValues,
        string searchText,
        out string reason)
    {
        reason = string.Empty;
        var keys = new[] { "Name", "FullName", "Code", "Description", "Title", "SystemName" };

        if (!string.IsNullOrWhiteSpace(searchText))
        {
            foreach (var key in keys)
            {
                if (targetValues.TryGetValue(key, out var targetValue) &&
                    targetValue.Contains(searchText, StringComparison.OrdinalIgnoreCase))
                {
                    reason = $"Search match on {key}";
                    return 90;
                }
            }

            if (targetValues.Values.Any(value => value.Contains(searchText, StringComparison.OrdinalIgnoreCase)))
            {
                reason = "Search match in target payload";
                return 50;
            }

            return 0;
        }

        foreach (var key in keys)
        {
            if (sourceValues.TryGetValue(key, out var sourceValue) &&
                targetValues.TryGetValue(key, out var targetValue) &&
                !string.IsNullOrWhiteSpace(sourceValue) &&
                sourceValue.Equals(targetValue, StringComparison.OrdinalIgnoreCase))
            {
                reason = $"Exact {key} match";
                return key.Equals("Code", StringComparison.OrdinalIgnoreCase) ? 100 : 95;
            }
        }

        var sourceDisplay = GetMetadataDisplayValue(sourceValues, string.Empty);
        if (!string.IsNullOrWhiteSpace(sourceDisplay))
        {
            foreach (var key in keys)
            {
                if (targetValues.TryGetValue(key, out var targetValue) &&
                    !string.IsNullOrWhiteSpace(targetValue) &&
                    (targetValue.Contains(sourceDisplay, StringComparison.OrdinalIgnoreCase) ||
                     sourceDisplay.Contains(targetValue, StringComparison.OrdinalIgnoreCase)))
                {
                    reason = $"Similar {key} value";
                    return 40;
                }
            }
        }

        return 0;
    }

    private static async Task<MetadataMigrationIdentityMapDetailsResponse> ReadIdentityMapDetailsAsync(
        SqlConnection cn,
        Guid runGuid,
        string schemaName,
        string tableName,
        bool includeIgnored,
        CancellationToken cancellationToken)
    {
        var response = new MetadataMigrationIdentityMapDetailsResponse();

        await using var cmd = new SqlCommand("SMigration.MetadataIdentityMapDetails_List", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = schemaName ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = tableName ?? string.Empty });
        cmd.Parameters.Add(new SqlParameter("@IncludeIgnored", SqlDbType.Bit) { Value = includeIgnored });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var row = new MetadataMigrationIdentityMapDetailRow
            {
                SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                TableName = Convert.ToString(reader["TableName"]) ?? string.Empty,
                SourceRowGuid = Convert.ToString(reader["SourceRowGuid"]) ?? string.Empty,
                SourceRowId = reader["SourceRowId"] == DBNull.Value ? 0 : Convert.ToInt64(reader["SourceRowId"]),
                TargetRowId = reader["TargetRowId"] == DBNull.Value ? 0 : Convert.ToInt64(reader["TargetRowId"]),
                DifferenceType = Convert.ToString(reader["DifferenceType"]) ?? string.Empty,
                SourceDisplayName = Convert.ToString(reader["SourceDisplayName"]) ?? string.Empty,
                IssueCode = Convert.ToString(reader["IssueCode"]) ?? string.Empty,
                IssueStatus = Convert.ToString(reader["IssueStatus"]) ?? string.Empty,
                Reason = Convert.ToString(reader["Reason"]) ?? string.Empty,
                SuggestedAction = Convert.ToString(reader["SuggestedAction"]) ?? string.Empty,
                IsResolved = reader["IsResolved"] != DBNull.Value && Convert.ToBoolean(reader["IsResolved"]),
                IsIgnoredIssue = reader["IsIgnoredIssue"] != DBNull.Value && Convert.ToBoolean(reader["IsIgnoredIssue"]),
                IgnoreReason = Convert.ToString(reader["IgnoreReason"]) ?? string.Empty,
                IgnoredOnUtc = Convert.ToString(reader["IgnoredOnUtc"]) ?? string.Empty,
                SourcePayloadJson = Convert.ToString(reader["SourcePayloadJson"]) ?? string.Empty,
                HasOverride = reader["HasOverride"] != DBNull.Value && Convert.ToBoolean(reader["HasOverride"]),
                OverrideTargetRowGuid = Convert.ToString(reader["OverrideTargetRowGuid"]) ?? string.Empty,
                OverrideTargetDisplayName = Convert.ToString(reader["OverrideTargetDisplayName"]) ?? string.Empty,
                OverrideReason = Convert.ToString(reader["OverrideReason"]) ?? string.Empty,
                OverrideColumnSourceSelectionJson = Convert.ToString(reader["OverrideColumnSourceSelectionJson"]) ?? string.Empty
            };

            if (row.IsResolved)
            {
                response.ResolvedCount++;
            }
            else if (row.IsIgnoredIssue)
            {
                response.IgnoredCount++;
            }
            else
            {
                response.UnresolvedCount++;
            }

            response.Rows.Add(row);
        }

        return response;
    }

    private static async Task<RepeatedField<MetadataMigrationIdentityMapRow>> ReadIdentityMapAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        var rows = new RepeatedField<MetadataMigrationIdentityMapRow>();
        await using var cmd = new SqlCommand(@"
DECLARE @TargetDatabaseName SYSNAME;

SELECT
    @TargetDatabaseName = r.TargetDatabaseName
FROM SMigration.Metadata_Run AS r
WHERE r.Guid = @RunGuid
  AND r.RowStatus NOT IN (0,254);

SELECT
    maprow.SchemaName,
    maprow.TableName,
    COUNT_BIG(1) AS MapRows,
    SUM(CASE
        WHEN maprow.TargetRowId IS NULL
         AND ISNULL(sr.DifferenceType, N'') <> N'Insert'
         AND ign.ID IS NULL
         AND ov.ID IS NULL THEN 1
        ELSE 0
    END) AS MissingTargetRows
FROM SMigration.Metadata_ApplyIdentityMap AS maprow
LEFT JOIN SMigration.Metadata_StagedRows AS sr
    ON sr.RunGuid = maprow.RunGuid
   AND sr.RegistryGuid = maprow.RegistryGuid
   AND sr.SourceRowGuid = maprow.SourceRowGuid
   AND sr.RowStatus NOT IN (0,254)
LEFT JOIN SMigration.Metadata_IdentityMapIgnoredIssues AS ign
    ON ign.DatabaseName = @TargetDatabaseName
   AND ign.RegistryGuid = maprow.RegistryGuid
   AND ign.SourceRowGuid = maprow.SourceRowGuid
   AND ign.IssueCode = N'TargetMissing'
   AND ign.RowStatus NOT IN (0,254)
LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
    ON ov.DatabaseName = @TargetDatabaseName
   AND ov.RegistryGuid = maprow.RegistryGuid
   AND ov.SourceRowGuid = maprow.SourceRowGuid
   AND ov.RowStatus NOT IN (0,254)
WHERE maprow.RunGuid = @RunGuid
  AND maprow.RowStatus NOT IN (0,254)
GROUP BY maprow.SchemaName, maprow.TableName
ORDER BY maprow.SchemaName, maprow.TableName;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            rows.Add(new MetadataMigrationIdentityMapRow
            {
                SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                TableName = Convert.ToString(reader["TableName"]) ?? string.Empty,
                MapRows = Convert.ToInt32(reader["MapRows"]),
                MissingTargetRows = Convert.ToInt32(reader["MissingTargetRows"])
            });
        }
        return rows;
    }

    private static async Task<RepeatedField<MetadataMigrationExecutionLogItem>> ReadExecutionLogAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        var rows = new RepeatedField<MetadataMigrationExecutionLogItem>();
        await using var cmd = new SqlCommand(@"
SELECT
    el.StepName,
    el.StepStatus,
    el.Message,
    el.DetailsJson,
    el.CreatedOnUtc
FROM SMigration.Metadata_ExecutionLog AS el
WHERE el.RunGuid = @RunGuid
  AND el.RowStatus NOT IN (0,254)
ORDER BY el.ID;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            rows.Add(new MetadataMigrationExecutionLogItem
            {
                StepName = Convert.ToString(reader["StepName"]) ?? string.Empty,
                StepStatus = Convert.ToString(reader["StepStatus"]) ?? string.Empty,
                Message = Convert.ToString(reader["Message"]) ?? string.Empty,
                DetailsJson = Convert.ToString(reader["DetailsJson"]) ?? string.Empty,
                CreatedOnUtc = Convert.ToString(reader["CreatedOnUtc"]) ?? string.Empty
            });
        }
        return rows;
    }

    private static void CopyDictionary(Dictionary<string, string> source, MapField<string, string> target)
    {
        foreach (var kvp in source)
        {
            target[kvp.Key] = kvp.Value;
        }
    }
}
