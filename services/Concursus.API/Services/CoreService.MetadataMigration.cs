using Concursus.API.Core;
using Google.Protobuf.Collections;
using Grpc.Core;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Concursus.API.Services;

public partial class CoreService
{
    public override async Task<MetadataMigrationRunResponse> MetadataMigrationRunCreate(
        MetadataMigrationRunCreateRequest request,
        ServerCallContext context)
    {
        try
        {
            await using var templateConnection = await OpenSqlAsync(context.CancellationToken);
            await using var cn = await OpenSqlForServerDatabaseAsync(
                templateConnection.ConnectionString,
                request.TargetServerName,
                request.TargetDatabaseName,
                context.CancellationToken);

            await ExecuteNonQueryAsync(cn, "SMigration.MetadataRegistry_Seed", context.CancellationToken);

            await using var cmd = new SqlCommand("SMigration.MetadataRun_Create", cn)
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

            return new MetadataMigrationRunResponse
            {
                Run = await ReadRunSummaryAsync(cn, runGuid, context.CancellationToken)
            };
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

    public override async Task<MetadataMigrationRunsResponse> MetadataMigrationRuns(
        MetadataMigrationRunsRequest request,
        ServerCallContext context)
    {
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
                    context.CancellationToken);
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

    public override async Task<MetadataMigrationBuildIdentityMapResponse> MetadataMigrationBuildIdentityMap(
        MetadataMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenTargetSqlFromRequestAsync(request, context.CancellationToken);
            await ExecuteRunProcedureAsync(cn, "SMigration.MetadataApplyIdentityMap_Build", runGuid, context.CancellationToken);

            var response = new MetadataMigrationBuildIdentityMapResponse();
            response.Rows.AddRange(await ReadIdentityMapAsync(cn, runGuid, context.CancellationToken));
            return response;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata identity map SQL failed: {ex.Message}"));
        }
    }

    public override async Task<MetadataMigrationApplyResponse> MetadataMigrationApply(
        MetadataMigrationApplyRequest request,
        ServerCallContext context)
    {
        var runGuid = ParseGuid(request.RunGuid, "runGuid");

        try
        {
            await using var cn = await OpenTargetSqlFromApplyRequestAsync(request, context.CancellationToken);
            await using var cmd = new SqlCommand("SMigration.MetadataApply_Run", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 600
            };

            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            cmd.Parameters.Add(new SqlParameter("@ForceApply", SqlDbType.Bit) { Value = request.ForceApply });
            cmd.Parameters.Add(new SqlParameter("@ApplySelectedOnly", SqlDbType.Bit) { Value = request.ApplySelectedOnly });

            await cmd.ExecuteNonQueryAsync(context.CancellationToken);

            return new MetadataMigrationApplyResponse
            {
                Message = request.ApplySelectedOnly
                    ? "Selected metadata records applied successfully."
                    : "Metadata apply completed successfully."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Metadata apply SQL failed: {ex.Message}"));
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

                await tx.CommitAsync(context.CancellationToken);
            }
            catch
            {
                await tx.RollbackAsync(context.CancellationToken);
                throw;
            }

            var selectedCount = await CountSelectedRowsAsync(cn, runGuid, context.CancellationToken);

            return new MetadataMigrationSelectionResponse
            {
                SelectedCount = selectedCount,
                Message = $"Metadata migration selection saved. {selectedCount} selected record(s)."
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
                {(hasIgnoreTable ? "CONVERT(nvarchar(30), ign.IgnoredOnUtc, 126)" : "CONVERT(nvarchar(30), N'')")} AS IgnoredOnUtc
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
                    IgnoredOnUtc = Convert.ToString(reader["IgnoredOnUtc"]) ?? string.Empty
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
                IgnoredOnUtc = stagedRow.IgnoredOnUtc
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


    private sealed class MetadataRegistryRow
    {
        public Guid RegistryGuid { get; init; }
        public string SchemaName { get; init; } = string.Empty;
        public string TableName { get; init; } = string.Empty;
        public string GuidColumnName { get; init; } = string.Empty;
        public string PrimaryKeyColumnName { get; init; } = string.Empty;
    }

    private sealed class MetadataPayloadRow
    {
        public Guid RowGuid { get; init; }
        public long? RowId { get; init; }
        public byte? RowStatus { get; init; }
        public string PayloadJson { get; init; } = "{}";
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

    private async Task<SqlConnection> OpenTargetSqlFromApplyRequestAsync(
        MetadataMigrationApplyRequest request,
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

    private static async Task StageMetadataWithTwoConnectionsAsync(
    SqlConnection sourceConnection,
    SqlConnection targetConnection,
    Guid runGuid,
    CancellationToken cancellationToken)
    {
        var registryRows = await ReadMetadataRegistryAsync(
            targetConnection,
            null,
            cancellationToken);

        if (registryRows.Count == 0)
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                "No enabled metadata registry rows exist. Run SMigration.MetadataRegistry_Seed first."));
        }

        var stagedRows = new List<(Guid RegistryGuid, MetadataPayloadRow SourceRow, byte[] SourceHash, string? TargetPayloadJson, byte[]? TargetHash, string DifferenceType)>();
        var validationIssues = new List<(Guid? RegistryGuid, Guid? SourceRowGuid, string Severity, string IssueCode, string IssueMessage, string DetailsJson)>();

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

            foreach (var sourceRow in sourceRows.Where(row => !duplicateGuids.Contains(row.RowGuid)))
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

            foreach (var row in stagedRows)
            {
                await InsertStagedRowAsync(
                    targetConnection,
                    tx,
                    runGuid,
                    row.RegistryGuid,
                    row.SourceRow,
                    row.SourceHash,
                    row.TargetPayloadJson,
                    row.TargetHash,
                    row.DifferenceType,
                    cancellationToken);
            }

            await ExecuteTargetNonQueryAsync(
            targetConnection,
            tx,
            """
            EXEC SMigration.MetadataStage_NormaliseDifferences
                @RunGuid = @RunGuid;

            EXEC SMigration.MetadataStage_NormaliseEnvironmentOnlyUpdates
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
            await tx.RollbackAsync(cancellationToken);
            throw;
        }
    }

    private static async Task<List<MetadataRegistryRow>> ReadMetadataRegistryAsync(
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

    private static async Task<bool> TableExistsAsync(
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

    private static async Task<bool> ColumnExistsAsync(
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

    private static async Task<HashSet<string>> ReadStageColumnNamesAsync(
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

    private static async Task<List<MetadataPayloadRow>> ReadMetadataPayloadRowsAsync(
        SqlConnection cn,
        SqlTransaction? tx,
        MetadataRegistryRow registry,
        IEnumerable<string> columnNames,
        bool activeOnly,
        CancellationToken cancellationToken)
    {
        var rows = new List<MetadataPayloadRow>();
        var orderedColumns = columnNames.OrderBy(column => column, StringComparer.OrdinalIgnoreCase).ToList();

        // Re-order to physical column order for stable JSON by querying has already been ordered before insertion into HashSet.
        // The payload comparison remains deterministic because both source and target use the same list here.
        var columnList = string.Join(", ", orderedColumns.Select(QuoteName));
        var objectName = $"{QuoteName(registry.SchemaName)}.{QuoteName(registry.TableName)}";
        var hasRowStatus = orderedColumns.Contains("RowStatus", StringComparer.OrdinalIgnoreCase);

        var whereClause = activeOnly && hasRowStatus
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

    private static async Task InsertStagedRowAsync(
        SqlConnection cn,
        SqlTransaction tx,
        Guid runGuid,
        Guid registryGuid,
        MetadataPayloadRow sourceRow,
        byte[] sourceHash,
        string? targetPayloadJson,
        byte[]? targetHash,
        string differenceType,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
INSERT INTO SMigration.Metadata_StagedRows
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    SourceRowId,
    SourceRowStatus,
    SourcePayloadJson,
    SourcePayloadHash,
    TargetPayloadJson,
    TargetPayloadHash,
    DifferenceType,
    CreatedOnUtc
)
VALUES
(
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    @SourceRowGuid,
    @SourceRowId,
    @SourceRowStatus,
    @SourcePayloadJson,
    @SourcePayloadHash,
    @TargetPayloadJson,
    @TargetPayloadHash,
    @DifferenceType,
    SYSUTCDATETIME()
);", cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        cmd.Parameters.Add(new SqlParameter("@RegistryGuid", SqlDbType.UniqueIdentifier) { Value = registryGuid });
        cmd.Parameters.Add(new SqlParameter("@SourceRowGuid", SqlDbType.UniqueIdentifier) { Value = sourceRow.RowGuid });
        cmd.Parameters.Add(new SqlParameter("@SourceRowId", SqlDbType.BigInt) { Value = sourceRow.RowId.HasValue ? (object)sourceRow.RowId.Value : DBNull.Value });
        cmd.Parameters.Add(new SqlParameter("@SourceRowStatus", SqlDbType.TinyInt) { Value = sourceRow.RowStatus.HasValue ? (object)sourceRow.RowStatus.Value : DBNull.Value });
        cmd.Parameters.Add(new SqlParameter("@SourcePayloadJson", SqlDbType.NVarChar, -1) { Value = sourceRow.PayloadJson });
        cmd.Parameters.Add(new SqlParameter("@SourcePayloadHash", SqlDbType.VarBinary, 32) { Value = sourceHash });
        cmd.Parameters.Add(new SqlParameter("@TargetPayloadJson", SqlDbType.NVarChar, -1) { Value = targetPayloadJson is null ? DBNull.Value : (object)targetPayloadJson });
        cmd.Parameters.Add(new SqlParameter("@TargetPayloadHash", SqlDbType.VarBinary, 32) { Value = targetHash is null ? DBNull.Value : (object)targetHash });
        cmd.Parameters.Add(new SqlParameter("@DifferenceType", SqlDbType.NVarChar, 30) { Value = differenceType });

        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task AddValidationIssueAsync(
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

    private static async Task AddExecutionLogAsync(
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

    private static async Task ExecuteTargetNonQueryAsync(
        SqlConnection cn,
        SqlTransaction tx,
        string sql,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(sql, cn, tx)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task UpdateStageRunSummaryAsync(
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

    private static byte[] ComputeSha256(string value) =>
        SHA256.HashData(Encoding.Unicode.GetBytes(value ?? string.Empty));

    private static string QuoteName(string identifier) =>
        $"[{identifier.Replace("]", "]]")}]";

    private static bool IsSafeSqlIdentifier(string identifier) =>
        !string.IsNullOrWhiteSpace(identifier) &&
        identifier.Length <= 128 &&
        identifier.All(ch => char.IsLetterOrDigit(ch) || ch == '_' || ch == '#');

    private static Guid ParseGuid(string value, string parameterName)
    {
        if (!Guid.TryParse(value, out var guid))
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, $"Invalid {parameterName}."));
        }

        return guid;
    }

    private static async Task ExecuteNonQueryAsync(SqlConnection cn, string procedureName, CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(procedureName, cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task ExecuteRunProcedureAsync(SqlConnection cn, string procedureName, Guid runGuid, CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(procedureName, cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 600
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
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
    vi.DetailsJson
FROM SMigration.Metadata_ValidationIssues AS vi
LEFT JOIN SMigration.Metadata_TableRegistry AS tr
    ON tr.Guid = vi.RegistryGuid
   AND tr.RowStatus NOT IN (0,254){ignoreJoin}
WHERE vi.RunGuid = @RunGuid
  AND vi.RowStatus NOT IN (0,254){ignoreFilter}
ORDER BY vi.Severity DESC, tr.SchemaName, tr.TableName, vi.IssueCode;";

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
            if (severity.Equals("Fail", StringComparison.OrdinalIgnoreCase)) response.FailCount++;
            if (severity.Equals("Warn", StringComparison.OrdinalIgnoreCase)) response.WarnCount++;
            if (severity.Equals("Info", StringComparison.OrdinalIgnoreCase)) response.InfoCount++;

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
                DetailsJson = Convert.ToString(reader["DetailsJson"]) ?? string.Empty
            });
        }
        return response;
    }

    private static async Task<RepeatedField<MetadataMigrationIdentityMapRow>> ReadIdentityMapAsync(SqlConnection cn, Guid runGuid, CancellationToken cancellationToken)
    {
        var rows = new RepeatedField<MetadataMigrationIdentityMapRow>();
        await using var cmd = new SqlCommand(@"
SELECT
    maprow.SchemaName,
    maprow.TableName,
    COUNT_BIG(1) AS MapRows,
    SUM(CASE WHEN maprow.TargetRowId IS NULL THEN 1 ELSE 0 END) AS MissingTargetRows
FROM SMigration.Metadata_ApplyIdentityMap AS maprow
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

    private static Dictionary<string, string> ParseJsonDictionary(string json)
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

    private static void CopyDictionary(Dictionary<string, string> source, MapField<string, string> target)
    {
        foreach (var kvp in source)
        {
            target[kvp.Key] = kvp.Value;
        }
    }
}
