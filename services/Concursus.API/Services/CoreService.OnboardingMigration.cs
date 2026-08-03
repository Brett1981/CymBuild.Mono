using Concursus.API.Core;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Text.Json;

namespace Concursus.API.Services;

[Authorize]
public partial class CoreService
{
    public override async Task<OnboardingMigrationStageResponse> OnboardingMigrationStage(
        OnboardingMigrationStageRequest request,
        ServerCallContext context)
    {
        var runGuid = string.IsNullOrWhiteSpace(request.RunGuid)
            ? Guid.NewGuid()
            : Guid.Parse(request.RunGuid);

        var response = new OnboardingMigrationStageResponse
        {
            RunGuid = runGuid.ToString()
        };
        try
        {
            var databaseContext = ResolveOnboardingDatabaseContext(
                request.SourceServerName,
                request.SourceDatabase,
                request.TargetServerName,
                request.TargetDatabaseName);

            if (!IsSameSqlServer(databaseContext.SourceServerName, databaseContext.TargetServerName))
            {
                return await OnboardingMigrationStageCrossServerAsync(
                    request,
                    databaseContext,
                    runGuid,
                    context.CancellationToken);
            }

            EnsureOnboardingSameServer(databaseContext);

            await using var cn = await OpenOnboardingTargetSqlAsync(
                databaseContext.TargetServerName,
                databaseContext.TargetDatabaseName,
                context.CancellationToken);
            await using var cmd = new SqlCommand("SMigration.OnboardingStage_LoadFromSource", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@SourceDatabase", SqlDbType.NVarChar, 128) { Value = databaseContext.SourceDatabaseName });
            cmd.Parameters.Add(new SqlParameter("@SourceServerName", SqlDbType.NVarChar, 128) { Value = databaseContext.SourceServerName });
            cmd.Parameters.Add(new SqlParameter("@TargetServerName", SqlDbType.NVarChar, 128) { Value = databaseContext.TargetServerName });
            cmd.Parameters.Add(new SqlParameter("@TargetDatabaseName", SqlDbType.NVarChar, 128) { Value = databaseContext.TargetDatabaseName });
            cmd.Parameters.Add(new SqlParameter("@BusinessUnitGroupGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Parse(request.BusinessUnitGroupGuid) });
            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 1000) { Value = request.Notes ?? string.Empty });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
            var stageSummaryFound = false;

            do
            {
                while (await reader.ReadAsync(context.CancellationToken))
                {
                    if (!HasOnboardingColumn(reader, "GroupCount"))
                    {
                        continue;
                    }

                    response.GroupCount = Convert.ToInt32(reader["GroupCount"]);
                    response.IdentityCount = Convert.ToInt32(reader["IdentityCount"]);
                    response.UserGroupCount = Convert.ToInt32(reader["UserGroupCount"]);
                    response.WorkflowNotificationGroupCount = Convert.ToInt32(reader["WorkflowNotificationGroupCount"]);
                    response.JobTypeCount = Convert.ToInt32(reader["JobTypeCount"]);
                    response.ActivityTypeCount = Convert.ToInt32(reader["ActivityTypeCount"]);
                    response.MilestoneTypeCount = Convert.ToInt32(reader["MilestoneTypeCount"]);
                    response.ProductCount = Convert.ToInt32(reader["ProductCount"]);
                    response.JobTypeActivityTypeCount = Convert.ToInt32(reader["JobTypeActivityTypeCount"]);
                    response.JobTypeMilestoneTemplateCount = Convert.ToInt32(reader["JobTypeMilestoneTemplateCount"]);
                    response.ProductJobActivityCount = Convert.ToInt32(reader["ProductJobActivityCount"]);
                    stageSummaryFound = true;
                    break;
                }

                if (stageSummaryFound)
                {
                    break;
                }
            }
            while (await reader.NextResultAsync(context.CancellationToken));

            if (!stageSummaryFound)
            {
                throw new RpcException(new Status(
                    StatusCode.Internal,
                    "Onboarding stage completed without returning the stage summary. This usually means the selected source business unit group could not be resolved to a source organisational unit. Reload lookups after the SQL patch and select a business unit shown by the filtered lookup, then stage again."));
            }
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                $"Onboarding stage SQL failed: {ex.Message}"));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new RpcException(new Status(
                StatusCode.Internal,
                $"Onboarding stage failed: {ex.Message}"));
        }
        return response;
    }

    public override async Task<OnboardingMigrationLookupResponse> OnboardingMigrationBusinessUnitGroups(
    OnboardingMigrationLookupRequest request,
    ServerCallContext context)
    {
        return await ReadLookupAsync(
            "SMigration.OnboardingLookup_BusinessUnitGroups",
            request.SourceServerName,
            request.SourceDatabase,
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);
    }


    public override async Task<OnboardingMigrationRunReserveResponse> OnboardingMigrationRunReserve(
        OnboardingMigrationRunReserveRequest request,
        ServerCallContext context)
    {
        if (!Guid.TryParse(request.BusinessUnitGroupGuid, out var businessUnitGroupGuid))
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                "BusinessUnitGroupGuid is required and must be a valid Guid."));
        }

        Guid? runGuid = null;
        if (!string.IsNullOrWhiteSpace(request.RunGuid))
        {
            if (!Guid.TryParse(request.RunGuid, out var parsedRunGuid))
            {
                throw new RpcException(new Status(
                    StatusCode.InvalidArgument,
                    "RunGuid must be blank or a valid Guid."));
            }

            runGuid = parsedRunGuid;
        }

        var databaseContext = ResolveOnboardingDatabaseContext(
            request.SourceServerName,
            request.SourceDatabase,
            request.TargetServerName,
            request.TargetDatabaseName);

        try
        {
            await using var cn = await OpenOnboardingTargetSqlAsync(
                databaseContext.TargetServerName,
                databaseContext.TargetDatabaseName,
                context.CancellationToken);

            await using var cmd = new SqlCommand("SMigration.OnboardingRun_Reserve", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier)
            {
                Value = runGuid.HasValue ? (object)runGuid.Value : DBNull.Value
            });
            cmd.Parameters.Add(new SqlParameter("@SourceDatabase", SqlDbType.NVarChar, 128) { Value = databaseContext.SourceDatabaseName });
            cmd.Parameters.Add(new SqlParameter("@SourceServerName", SqlDbType.NVarChar, 128) { Value = databaseContext.SourceServerName });
            cmd.Parameters.Add(new SqlParameter("@TargetServerName", SqlDbType.NVarChar, 128) { Value = databaseContext.TargetServerName });
            cmd.Parameters.Add(new SqlParameter("@TargetDatabaseName", SqlDbType.NVarChar, 128) { Value = databaseContext.TargetDatabaseName });
            cmd.Parameters.Add(new SqlParameter("@BusinessUnitGroupGuid", SqlDbType.UniqueIdentifier) { Value = businessUnitGroupGuid });
            cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 1000) { Value = request.Notes ?? string.Empty });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
            if (!await reader.ReadAsync(context.CancellationToken))
            {
                throw new RpcException(new Status(
                    StatusCode.Internal,
                    "OnBoarding run reserve did not return a run summary."));
            }

            return new OnboardingMigrationRunReserveResponse
            {
                RunSummary = MapOnboardingRunSummary(reader),
                Message = "OnBoarding run reserved."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                $"Onboarding run reserve SQL failed: {ex.Message}"));
        }
    }

    public override async Task<OnboardingMigrationLookupResponse> OnboardingMigrationRuns(
        OnboardingMigrationLookupRequest request,
        ServerCallContext context)
    {
        return await ReadLookupAsync(
            "SMigration.OnboardingLookup_Runs",
            request.SourceServerName,
            request.SourceDatabase,
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);
    }

    private async Task<OnboardingMigrationLookupResponse> ReadLookupAsync(
    string procedureName,
    string sourceServerName,
    string sourceDatabase,
    string targetServerName,
    string targetDatabaseName,
    CancellationToken cancellationToken)
    {
        var response = new OnboardingMigrationLookupResponse();
        var databaseContext = ResolveOnboardingDatabaseContext(
            sourceServerName,
            sourceDatabase,
            targetServerName,
            targetDatabaseName);

        var isBusinessUnitLookup = string.Equals(
            procedureName,
            "SMigration.OnboardingLookup_BusinessUnitGroups",
            StringComparison.OrdinalIgnoreCase);

        if (isBusinessUnitLookup && !IsSameSqlServer(databaseContext.SourceServerName, databaseContext.TargetServerName))
        {
            return await ReadBusinessUnitGroupsCrossServerAsync(databaseContext, cancellationToken);
        }

        if (isBusinessUnitLookup)
        {
            EnsureOnboardingSameServer(databaseContext);
        }

        var safeSourceDatabase = databaseContext.SourceDatabaseName;

        if (isBusinessUnitLookup && string.IsNullOrWhiteSpace(safeSourceDatabase))
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                "Source database is required."));
        }

        await using var cn = await OpenOnboardingTargetSqlAsync(
            databaseContext.TargetServerName,
            databaseContext.TargetDatabaseName,
            cancellationToken);

        if (isBusinessUnitLookup)
        {
            await using var checkCmd = new SqlCommand(
                @"
        SELECT
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM sys.databases
                    WHERE name = @SourceDatabase
                )
                THEN 1
                ELSE 0
            END;", cn);
            checkCmd.CommandType = CommandType.Text;
            checkCmd.CommandTimeout = 30;
            checkCmd.Parameters.Add(new SqlParameter("@SourceDatabase", SqlDbType.NVarChar, 128)
            {
                Value = safeSourceDatabase
            });

            var exists = Convert.ToInt32(await checkCmd.ExecuteScalarAsync(cancellationToken));

            if (exists != 1)
            {
                throw new RpcException(new Status(
                    StatusCode.InvalidArgument,
                    $"Source database '{safeSourceDatabase}' was not found on SQL Server '{databaseContext.TargetServerName}'. " +
                    "For same-server OnBoarding, choose a source database on the target SQL Server. For cross-server OnBoarding, enter a different Source Server and the API will read from that source connection."));
            }
        }

        try
        {
            await using var cmd = new SqlCommand(procedureName, cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@SourceDatabase", SqlDbType.NVarChar, 128)
            {
                Value = safeSourceDatabase
            });

            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

            while (await reader.ReadAsync(cancellationToken))
            {
                response.Items.Add(new OnboardingMigrationLookupItem
                {
                    Guid = Convert.ToString(reader["Guid"]) ?? string.Empty,
                    Name = Convert.ToString(reader["Name"]) ?? string.Empty,
                    Code = Convert.ToString(reader["Code"]) ?? string.Empty,
                    Description = Convert.ToString(reader["Description"]) ?? string.Empty
                });
            }
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                $"Onboarding lookup SQL failed in {procedureName}: {ex.Message}"));
        }

        return response;
    }


    public override async Task<OnboardingMigrationEntityScopeResponse> OnboardingMigrationEntityScopeList(
        OnboardingMigrationEntityScopeRequest request,
        ServerCallContext context)
    {
        var response = new OnboardingMigrationEntityScopeResponse();

        try
        {
            await using var cn = await OpenOnboardingTargetSqlAsync(
                request.TargetServerName,
                request.TargetDatabaseName,
                context.CancellationToken);
            await using var cmd = new SqlCommand("SMigration.OnboardingEntityScope_List", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@SearchText", SqlDbType.NVarChar, 250)
            {
                Value = request.SearchText ?? string.Empty
            });
            cmd.Parameters.Add(new SqlParameter("@IncludeInactive", SqlDbType.Bit)
            {
                Value = request.IncludeInactive
            });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.Items.Add(new OnboardingMigrationEntityScopeItem
                {
                    EntityScopeGuid = Convert.ToString(reader["EntityScopeGuid"]) ?? string.Empty,
                    Code = Convert.ToString(reader["Code"]) ?? string.Empty,
                    Name = Convert.ToString(reader["Name"]) ?? string.Empty,
                    Description = Convert.ToString(reader["Description"]) ?? string.Empty,
                    StageTableName = Convert.ToString(reader["StageTableName"]) ?? string.Empty,
                    ScopeCategory = HasOnboardingColumn(reader, "Category") ? Convert.ToString(reader["Category"]) ?? string.Empty : string.Empty,
                    ScopeType = HasOnboardingColumn(reader, "ScopeType") ? Convert.ToString(reader["ScopeType"]) ?? string.Empty : string.Empty,
                    IsImplemented = HasOnboardingColumn(reader, "IsImplemented") && Convert.ToBoolean(reader["IsImplemented"]),
                    IsSupportData = HasOnboardingColumn(reader, "IsSupportData") && Convert.ToBoolean(reader["IsSupportData"]),
                    HandlerKey = HasOnboardingColumn(reader, "HandlerKey") ? Convert.ToString(reader["HandlerKey"]) ?? string.Empty : string.Empty,
                    PrimaryEntityTypeGuid = HasOnboardingColumn(reader, "PrimaryEntityTypeGuid") ? Convert.ToString(reader["PrimaryEntityTypeGuid"]) ?? string.Empty : string.Empty,
                    SourceSchemaName = HasOnboardingColumn(reader, "SourceSchemaName") ? Convert.ToString(reader["SourceSchemaName"]) ?? string.Empty : string.Empty,
                    SourceTableName = HasOnboardingColumn(reader, "SourceTableName") ? Convert.ToString(reader["SourceTableName"]) ?? string.Empty : string.Empty,
                    DisplayOrder = Convert.ToInt32(reader["DisplayOrder"]),
                    DefaultSelected = Convert.ToBoolean(reader["DefaultSelected"]),
                    CanDeselect = Convert.ToBoolean(reader["CanDeselect"]),
                    IsRequired = Convert.ToBoolean(reader["IsRequired"]),
                    RequiredDependencyCodes = Convert.ToString(reader["RequiredDependencyCodes"]) ?? string.Empty,
                    RowStatus = Convert.ToInt32(reader["RowStatus"])
                });
            }

            return response;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                $"Onboarding entity scope SQL failed: {ex.Message}"));
        }
    }

    public override async Task<OnboardingMigrationEntitySelectionResponse> OnboardingMigrationRunEntitySelectionDefault(
        OnboardingMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = Guid.Parse(request.RunGuid);

        await using var cn = await OpenOnboardingTargetSqlAsync(
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);
        await using (var cmd = new SqlCommand("SMigration.OnboardingRunEntitySelection_Default", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        })
        {
            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            await cmd.ExecuteNonQueryAsync(context.CancellationToken);
        }

        return await ReadRunEntitySelectionsAsync(cn, runGuid, context.CancellationToken);
    }

    public override async Task<OnboardingMigrationEntitySelectionResponse> OnboardingMigrationRunEntitySelectionList(
        OnboardingMigrationRunRequest request,
        ServerCallContext context)
    {
        var runGuid = Guid.Parse(request.RunGuid);

        await using var cn = await OpenOnboardingTargetSqlAsync(
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);
        return await ReadRunEntitySelectionsAsync(cn, runGuid, context.CancellationToken);
    }

    public override async Task<OnboardingMigrationEntitySelectionSaveResponse> OnboardingMigrationRunEntitySelectionSave(
        OnboardingMigrationEntitySelectionSaveRequest request,
        ServerCallContext context)
    {
        var runGuid = Guid.Parse(request.RunGuid);
        var selectionsJson = JsonSerializer.Serialize(
            request.Selections.Select(x => new
            {
                x.EntityCode,
                x.IsSelected
            }));

        await using var cn = await OpenOnboardingTargetSqlAsync(
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);

        try
        {
            await using var cmd = new SqlCommand("SMigration.OnboardingRunEntitySelection_Save", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            cmd.Parameters.Add(new SqlParameter("@SelectionsJson", SqlDbType.NVarChar, -1) { Value = selectionsJson });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);

            var response = new OnboardingMigrationEntitySelectionSaveResponse
            {
                Message = "OnBoarding entity scope saved. Re-stage the run if staged data already exists."
            };

            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.Items.Add(MapRunEntitySelection(reader));
            }

            return response;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                $"Onboarding entity selection SQL failed: {ex.Message}"));
        }
    }


    private static OnboardingMigrationRunSummary MapOnboardingRunSummary(IDataRecord reader) =>
        new()
        {
            RunGuid = Convert.ToString(reader["RunGuid"]) ?? string.Empty,
            SourceDatabase = Convert.ToString(reader["SourceDatabase"]) ?? string.Empty,
            SourceBusinessUnitGroupGuid = Convert.ToString(reader["SourceBusinessUnitGroupGuid"]) ?? string.Empty,
            Notes = Convert.ToString(reader["Notes"]) ?? string.Empty,
            CreatedUtc = Convert.ToString(reader["CreatedUtc"]) ?? string.Empty,
            CreatedBy = Convert.ToString(reader["CreatedBy"]) ?? string.Empty,
            SourceServerName = HasOnboardingColumn(reader, "SourceServerName") ? Convert.ToString(reader["SourceServerName"]) ?? string.Empty : string.Empty,
            TargetServerName = HasOnboardingColumn(reader, "TargetServerName") ? Convert.ToString(reader["TargetServerName"]) ?? string.Empty : string.Empty,
            TargetDatabaseName = HasOnboardingColumn(reader, "TargetDatabaseName") ? Convert.ToString(reader["TargetDatabaseName"]) ?? string.Empty : string.Empty
        };

    private static OnboardingMigrationEntitySelectionItem MapRunEntitySelection(SqlDataReader reader) =>
        new()
        {
            EntityScopeGuid = Convert.ToString(reader["EntityScopeGuid"]) ?? string.Empty,
            EntityCode = Convert.ToString(reader["EntityCode"]) ?? string.Empty,
            EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
            Description = Convert.ToString(reader["Description"]) ?? string.Empty,
            StageTableName = Convert.ToString(reader["StageTableName"]) ?? string.Empty,
            ScopeCategory = HasOnboardingColumn(reader, "Category") ? Convert.ToString(reader["Category"]) ?? string.Empty : string.Empty,
            ScopeType = HasOnboardingColumn(reader, "ScopeType") ? Convert.ToString(reader["ScopeType"]) ?? string.Empty : string.Empty,
            IsImplemented = HasOnboardingColumn(reader, "IsImplemented") && Convert.ToBoolean(reader["IsImplemented"]),
            IsSupportData = HasOnboardingColumn(reader, "IsSupportData") && Convert.ToBoolean(reader["IsSupportData"]),
            HandlerKey = HasOnboardingColumn(reader, "HandlerKey") ? Convert.ToString(reader["HandlerKey"]) ?? string.Empty : string.Empty,
            PrimaryEntityTypeGuid = HasOnboardingColumn(reader, "PrimaryEntityTypeGuid") ? Convert.ToString(reader["PrimaryEntityTypeGuid"]) ?? string.Empty : string.Empty,
            SourceSchemaName = HasOnboardingColumn(reader, "SourceSchemaName") ? Convert.ToString(reader["SourceSchemaName"]) ?? string.Empty : string.Empty,
            SourceTableName = HasOnboardingColumn(reader, "SourceTableName") ? Convert.ToString(reader["SourceTableName"]) ?? string.Empty : string.Empty,
            DisplayOrder = Convert.ToInt32(reader["DisplayOrder"]),
            IsSelected = Convert.ToBoolean(reader["IsSelected"]),
            DefaultSelected = Convert.ToBoolean(reader["DefaultSelected"]),
            CanDeselect = Convert.ToBoolean(reader["CanDeselect"]),
            IsRequired = Convert.ToBoolean(reader["IsRequired"]),
            RequiredDependencyCodes = Convert.ToString(reader["RequiredDependencyCodes"]) ?? string.Empty,
            SelectionGuid = Convert.ToString(reader["SelectionGuid"]) ?? string.Empty,
            SelectionSource = Convert.ToString(reader["SelectionSource"]) ?? string.Empty,
            SelectedOnUtc = Convert.ToString(reader["SelectedOnUtc"]) ?? string.Empty
        };

    private static async Task<OnboardingMigrationEntitySelectionResponse> ReadRunEntitySelectionsAsync(
        SqlConnection cn,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        var response = new OnboardingMigrationEntitySelectionResponse();

        await using var cmd = new SqlCommand("SMigration.OnboardingRunEntitySelection_List", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            response.Items.Add(MapRunEntitySelection(reader));
        }

        return response;
    }

    public override async Task<OnboardingMigrationValidateResponse> OnboardingMigrationValidate(
        OnboardingMigrationRunRequest request,
        ServerCallContext context)
    {
        var response = new OnboardingMigrationValidateResponse();

        await using var cn = await OpenOnboardingTargetSqlAsync(
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);
        await using var cmd = new SqlCommand("SMigration.OnboardingValidate", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Parse(request.RunGuid) });

        await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
        while (await reader.ReadAsync(context.CancellationToken))
        {
            response.ValidationIssues.Add(new OnboardingMigrationValidationIssue
            {
                EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
                StageTable = Convert.ToString(reader["StageTable"]) ?? string.Empty,
                StageGuid = Convert.ToString(reader["StageGuid"]) ?? string.Empty,
                Severity = Convert.ToString(reader["Severity"]) ?? string.Empty,
                IssueCode = Convert.ToString(reader["IssueCode"]) ?? string.Empty,
                IssueMessage = Convert.ToString(reader["IssueMessage"]) ?? string.Empty
            });
        }

        return response;
    }

    public override async Task<OnboardingMigrationApplyResponse> OnboardingMigrationApply(
        OnboardingMigrationApplyRequest request,
        ServerCallContext context)
    {
        try
        {
            await using var cn = await OpenOnboardingTargetSqlAsync(
                request.TargetServerName,
                request.TargetDatabaseName,
                context.CancellationToken);

            await using var cmd = new SqlCommand("SMigration.OnboardingImport_Apply", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier)
            {
                Value = Guid.Parse(request.RunGuid)
            });

            cmd.Parameters.Add(new SqlParameter("@AllowWarnings", SqlDbType.Bit)
            {
                Value = request.AllowWarnings
            });

            cmd.Parameters.Add(new SqlParameter("@PreviewOnly", SqlDbType.Bit)
            {
                Value = request.PreviewOnly
            });

            await cmd.ExecuteNonQueryAsync(context.CancellationToken);

            return new OnboardingMigrationApplyResponse
            {
                Message = request.PreviewOnly
                    ? "Preview completed. No changes were applied."
                    : "Migration apply completed successfully."
            };
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                $"Onboarding apply SQL failed: {ex.Message}"));
        }
        catch (Exception ex)
        {
            throw new RpcException(new Status(
                StatusCode.Internal,
                $"Onboarding apply failed: {ex.Message}"));
        }
    }

    public override async Task<OnboardingMigrationReportResponse> OnboardingMigrationReport(
        OnboardingMigrationRunRequest request,
        ServerCallContext context)
    {
        var response = new OnboardingMigrationReportResponse();

        await using var cn = await OpenOnboardingTargetSqlAsync(
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);
        await using var cmd = new SqlCommand("SMigration.OnboardingReport", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Parse(request.RunGuid) });

        await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);

        if (await reader.ReadAsync(context.CancellationToken))
        {
            response.RunSummary = MapOnboardingRunSummary(reader);
        }

        if (await reader.NextResultAsync(context.CancellationToken))
        {
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.StagedCounts.Add(new OnboardingMigrationEntityCount
                {
                    EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
                    Count = Convert.ToInt32(reader["StagedCount"])
                });
            }
        }

        if (await reader.NextResultAsync(context.CancellationToken))
        {
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.ValidationIssues.Add(new OnboardingMigrationValidationIssue
                {
                    EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
                    StageTable = Convert.ToString(reader["StageTable"]) ?? string.Empty,
                    StageGuid = Convert.ToString(reader["StageGuid"]) ?? string.Empty,
                    Severity = Convert.ToString(reader["Severity"]) ?? string.Empty,
                    IssueCode = Convert.ToString(reader["IssueCode"]) ?? string.Empty,
                    IssueMessage = Convert.ToString(reader["IssueMessage"]) ?? string.Empty
                });
            }
        }

        if (await reader.NextResultAsync(context.CancellationToken))
        {
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.ExecutionLog.Add(new OnboardingMigrationExecutionLogItem
                {
                    StepName = Convert.ToString(reader["StepName"]) ?? string.Empty,
                    EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
                    ActionName = Convert.ToString(reader["ActionName"]) ?? string.Empty,
                    AffectedCount = Convert.ToInt32(reader["AffectedCount"]),
                    Details = Convert.ToString(reader["Details"]) ?? string.Empty,
                    LoggedUtc = Convert.ToString(reader["LoggedUtc"]) ?? string.Empty
                });
            }
        }

        return response;
    }

    public override async Task<OnboardingMigrationStagedDataResponse> OnboardingMigrationStagedData(
        OnboardingMigrationStagedDataRequest request,
        ServerCallContext context)
    {
        var response = new OnboardingMigrationStagedDataResponse();

        await using var cn = await OpenOnboardingTargetSqlAsync(
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);
        await using var cmd = new SqlCommand("SMigration.OnboardingReport_StagedData", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Parse(request.RunGuid) });
        cmd.Parameters.Add(new SqlParameter("@EntityName", SqlDbType.NVarChar, 200) { Value = request.EntityName ?? string.Empty });

        await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
        while (await reader.ReadAsync(context.CancellationToken))
        {
            var row = new OnboardingMigrationStagedRow
            {
                EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
                RowGuid = Convert.ToString(reader["RowGuid"]) ?? string.Empty
            };

            var json = Convert.ToString(reader["ValuesJson"]) ?? "{}";
            var values = JsonSerializer.Deserialize<Dictionary<string, string>>(json) ?? new Dictionary<string, string>();
            foreach (var kvp in values)
            {
                row.Values.Add(kvp.Key, kvp.Value);
            }

            response.Rows.Add(row);
        }

        return response;
    }


    public override async Task<OnboardingMigrationStageSelectionResponse> OnboardingMigrationStageSelectionList(
        OnboardingMigrationRunRequest request,
        ServerCallContext context)
    {
        var response = new OnboardingMigrationStageSelectionResponse();

        await using var cn = await OpenOnboardingTargetSqlAsync(
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);
        await using var cmd = new SqlCommand("SMigration.OnboardingRunStageSelection_List", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier)
        {
            Value = Guid.Parse(request.RunGuid)
        });

        await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
        while (await reader.ReadAsync(context.CancellationToken))
        {
            response.Selections.Add(new OnboardingMigrationStageSelectionItem
            {
                EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
                RowGuid = Convert.ToString(reader["RowGuid"]) ?? string.Empty,
                SelectedOnUtc = Convert.ToString(reader["SelectedOnUtc"]) ?? string.Empty
            });
        }

        return response;
    }

    public override async Task<OnboardingMigrationStageSelectionResponse> OnboardingMigrationStageSelectionSave(
        OnboardingMigrationStageSelectionSaveRequest request,
        ServerCallContext context)
    {
        var response = new OnboardingMigrationStageSelectionResponse();

        var selections = request.Selections.Select(x => new
        {
            EntityName = x.EntityName ?? string.Empty,
            RowGuid = x.RowGuid ?? string.Empty
        }).ToList();

        var selectionsJson = JsonSerializer.Serialize(selections);

        await using var cn = await OpenOnboardingTargetSqlAsync(
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);
        await using var cmd = new SqlCommand("SMigration.OnboardingRunStageSelection_Save", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier)
        {
            Value = Guid.Parse(request.RunGuid)
        });
        cmd.Parameters.Add(new SqlParameter("@SelectionsJson", SqlDbType.NVarChar, -1)
        {
            Value = selectionsJson
        });

        await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
        while (await reader.ReadAsync(context.CancellationToken))
        {
            response.Selections.Add(new OnboardingMigrationStageSelectionItem
            {
                EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
                RowGuid = Convert.ToString(reader["RowGuid"]) ?? string.Empty,
                SelectedOnUtc = Convert.ToString(reader["SelectedOnUtc"]) ?? string.Empty
            });
        }

        return response;
    }

    public override async Task<OnboardingMigrationDiffResponse> OnboardingMigrationDiff(
        OnboardingMigrationDiffRequest request,
        ServerCallContext context)
    {
        var response = new OnboardingMigrationDiffResponse();

        await using var cn = await OpenOnboardingTargetSqlAsync(
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);
        await using var cmd = new SqlCommand("SMigration.OnboardingDiff_Report", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Parse(request.RunGuid) });
        cmd.Parameters.Add(new SqlParameter("@EntityName", SqlDbType.NVarChar, 200) { Value = request.EntityName ?? string.Empty });

        await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
        while (await reader.ReadAsync(context.CancellationToken))
        {
            var row = new OnboardingMigrationDiffRow
            {
                EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
                RowGuid = Convert.ToString(reader["RowGuid"]) ?? string.Empty,
                DiffType = Convert.ToString(reader["DiffType"]) ?? string.Empty
            };

            var sourceJson = Convert.ToString(reader["SourceValuesJson"]) ?? "{}";
            var targetJson = Convert.ToString(reader["TargetValuesJson"]) ?? "{}";
            var differingColumnsJson = Convert.ToString(reader["DifferingColumnsJson"]) ?? "[]";

            var sourceValues = JsonSerializer.Deserialize<Dictionary<string, string>>(sourceJson) ?? new Dictionary<string, string>();
            var targetValues = JsonSerializer.Deserialize<Dictionary<string, string>>(targetJson) ?? new Dictionary<string, string>();
            var differingColumns = JsonSerializer.Deserialize<List<string>>(differingColumnsJson) ?? new List<string>();

            foreach (var kvp in sourceValues)
            {
                row.SourceValues.Add(kvp.Key, kvp.Value);
            }

            foreach (var kvp in targetValues)
            {
                row.TargetValues.Add(kvp.Key, kvp.Value);
            }

            row.DifferingColumns.AddRange(differingColumns);
            response.Rows.Add(row);
        }

        return response;
    }

    public override async Task<OnboardingMigrationAuditDashboardResponse> OnboardingMigrationAuditDashboard(
        OnboardingMigrationAuditDashboardRequest request,
        ServerCallContext context)
    {
        var response = new OnboardingMigrationAuditDashboardResponse();

        await using var cn = await OpenOnboardingTargetSqlAsync(
            request.TargetServerName,
            request.TargetDatabaseName,
            context.CancellationToken);
        await using var cmd = new SqlCommand("SMigration.OnboardingAuditDashboard", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Parse(request.RunGuid) });

        await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);

        if (await reader.ReadAsync(context.CancellationToken))
        {
            response.Summary = new OnboardingMigrationAuditDashboardSummary
            {
                StagedEntityCount = Convert.ToInt32(reader["StagedEntityCount"]),
                TotalStagedRows = Convert.ToInt32(reader["TotalStagedRows"]),
                ValidationErrorCount = Convert.ToInt32(reader["ValidationErrorCount"]),
                ValidationWarningCount = Convert.ToInt32(reader["ValidationWarningCount"]),
                ExecutionLogCount = Convert.ToInt32(reader["ExecutionLogCount"]),
                InsertedRowCount = Convert.ToInt32(reader["InsertedRowCount"]),
                UpdatedRowCount = Convert.ToInt32(reader["UpdatedRowCount"])
            };
        }

        if (await reader.NextResultAsync(context.CancellationToken))
        {
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.StagedCounts.Add(new OnboardingMigrationEntityCount
                {
                    EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
                    Count = Convert.ToInt32(reader["Count"])
                });
            }
        }

        if (await reader.NextResultAsync(context.CancellationToken))
        {
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.ValidationIssues.Add(new OnboardingMigrationValidationIssue
                {
                    EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
                    StageTable = Convert.ToString(reader["StageTable"]) ?? string.Empty,
                    StageGuid = Convert.ToString(reader["StageGuid"]) ?? string.Empty,
                    Severity = Convert.ToString(reader["Severity"]) ?? string.Empty,
                    IssueCode = Convert.ToString(reader["IssueCode"]) ?? string.Empty,
                    IssueMessage = Convert.ToString(reader["IssueMessage"]) ?? string.Empty
                });
            }
        }

        if (await reader.NextResultAsync(context.CancellationToken))
        {
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.ExecutionLog.Add(new OnboardingMigrationExecutionLogItem
                {
                    StepName = Convert.ToString(reader["StepName"]) ?? string.Empty,
                    EntityName = Convert.ToString(reader["EntityName"]) ?? string.Empty,
                    ActionName = Convert.ToString(reader["ActionName"]) ?? string.Empty,
                    AffectedCount = Convert.ToInt32(reader["AffectedCount"]),
                    Details = Convert.ToString(reader["Details"]) ?? string.Empty,
                    LoggedUtc = Convert.ToString(reader["LoggedUtc"]) ?? string.Empty
                });
            }
        }

        return response;
    }


    private async Task<SqlConnection> OpenOnboardingTargetSqlAsync(
        string? targetServerName,
        string? targetDatabaseName,
        CancellationToken cancellationToken)
    {
        await using var templateConnection = await OpenSqlAsync(cancellationToken);
        var builder = new SqlConnectionStringBuilder(templateConnection.ConnectionString);

        var resolvedServerName = string.IsNullOrWhiteSpace(targetServerName)
            ? builder.DataSource
            : targetServerName.Trim();

        var resolvedDatabaseName = string.IsNullOrWhiteSpace(targetDatabaseName)
            ? builder.InitialCatalog
            : targetDatabaseName.Trim();

        return await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            resolvedServerName,
            resolvedDatabaseName,
            cancellationToken);
    }

    private OnboardingDatabaseContext ResolveOnboardingDatabaseContext(
        string? sourceServerName,
        string? sourceDatabaseName,
        string? targetServerName,
        string? targetDatabaseName)
    {
        var builder = new SqlConnectionStringBuilder(ResolveSqlConnectionString());
        var resolvedTargetServerName = string.IsNullOrWhiteSpace(targetServerName)
            ? builder.DataSource
            : targetServerName.Trim();
        var resolvedTargetDatabaseName = string.IsNullOrWhiteSpace(targetDatabaseName)
            ? builder.InitialCatalog
            : targetDatabaseName.Trim();
        var resolvedSourceServerName = string.IsNullOrWhiteSpace(sourceServerName)
            ? resolvedTargetServerName
            : sourceServerName.Trim();
        var resolvedSourceDatabaseName = (sourceDatabaseName ?? string.Empty).Trim();

        return new OnboardingDatabaseContext(
            resolvedSourceServerName,
            resolvedSourceDatabaseName,
            resolvedTargetServerName,
            resolvedTargetDatabaseName);
    }

    private static void EnsureOnboardingSameServer(OnboardingDatabaseContext databaseContext)
    {
        if (!IsSameSqlServer(databaseContext.SourceServerName, databaseContext.TargetServerName))
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                $"Cross-server OnBoarding is not enabled in R2A. Source server '{databaseContext.SourceServerName}' and target server '{databaseContext.TargetServerName}' must match until the cross-server staging phase is applied."));
        }
    }

    private static bool HasOnboardingColumn(IDataRecord reader, string columnName)
    {
        for (var ordinal = 0; ordinal < reader.FieldCount; ordinal++)
        {
            if (string.Equals(reader.GetName(ordinal), columnName, StringComparison.OrdinalIgnoreCase))
                return true;
        }

        return false;
    }

    private sealed record OnboardingDatabaseContext(
        string SourceServerName,
        string SourceDatabaseName,
        string TargetServerName,
        string TargetDatabaseName);

}
