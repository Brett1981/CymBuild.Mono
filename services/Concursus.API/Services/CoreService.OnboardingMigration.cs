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
            await using var cn = await OpenSqlAsync(context.CancellationToken);
            await using var cmd = new SqlCommand("SMigration.OnboardingStage_LoadFromSource", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@SourceDatabase", SqlDbType.NVarChar, 128) { Value = request.SourceDatabase ?? string.Empty });
            cmd.Parameters.Add(new SqlParameter("@BusinessUnitGroupGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Parse(request.BusinessUnitGroupGuid) });
            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 1000) { Value = request.Notes ?? string.Empty });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
            if (await reader.ReadAsync(context.CancellationToken))
            {
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
            }
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                $"Onboarding stage SQL failed: {ex.Message}"));
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
            request.SourceDatabase,
            context.CancellationToken);
    }

    public override async Task<OnboardingMigrationLookupResponse> OnboardingMigrationRuns(
        OnboardingMigrationLookupRequest request,
        ServerCallContext context)
    {
        return await ReadLookupAsync(
            "SMigration.OnboardingLookup_Runs",
            request.SourceDatabase,
            context.CancellationToken);
    }

    private async Task<OnboardingMigrationLookupResponse> ReadLookupAsync(
    string procedureName,
    string sourceDatabase,
    CancellationToken cancellationToken)
    {
        var response = new OnboardingMigrationLookupResponse();
        var safeSourceDatabase = sourceDatabase?.Trim() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(safeSourceDatabase))
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                "Source database is required."));
        }

        await using var cn = await OpenSqlAsync(cancellationToken);

        await using (var checkCmd = new SqlCommand(
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
            END;", cn))
        {
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
                    $"Source database '{safeSourceDatabase}' was not found on the current SQL Server instance. " +
                    "Onboarding migration requires source and target databases to be on the same SQL Server instance."));
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

    public override async Task<OnboardingMigrationValidateResponse> OnboardingMigrationValidate(
        OnboardingMigrationRunRequest request,
        ServerCallContext context)
    {
        var response = new OnboardingMigrationValidateResponse();

        await using var cn = await OpenSqlAsync(context.CancellationToken);
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
            await using var cn = await OpenSqlAsync(context.CancellationToken);

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

        await using var cn = await OpenSqlAsync(context.CancellationToken);
        await using var cmd = new SqlCommand("SMigration.OnboardingReport", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Parse(request.RunGuid) });

        await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);

        if (await reader.ReadAsync(context.CancellationToken))
        {
            response.RunSummary = new OnboardingMigrationRunSummary
            {
                RunGuid = Convert.ToString(reader["RunGuid"]) ?? string.Empty,
                SourceDatabase = Convert.ToString(reader["SourceDatabase"]) ?? string.Empty,
                SourceBusinessUnitGroupGuid = Convert.ToString(reader["SourceBusinessUnitGroupGuid"]) ?? string.Empty,
                Notes = Convert.ToString(reader["Notes"]) ?? string.Empty,
                CreatedUtc = Convert.ToString(reader["CreatedUtc"]) ?? string.Empty,
                CreatedBy = Convert.ToString(reader["CreatedBy"]) ?? string.Empty
            };
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

        await using var cn = await OpenSqlAsync(context.CancellationToken);
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

    public override async Task<OnboardingMigrationDiffResponse> OnboardingMigrationDiff(
        OnboardingMigrationDiffRequest request,
        ServerCallContext context)
    {
        var response = new OnboardingMigrationDiffResponse();

        await using var cn = await OpenSqlAsync(context.CancellationToken);
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

        await using var cn = await OpenSqlAsync(context.CancellationToken);
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
}