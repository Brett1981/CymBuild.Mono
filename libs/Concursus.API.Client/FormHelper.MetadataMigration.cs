using Concursus.API.Client.Models.MetadataMigration;
using Concursus.API.Core;
using System.Linq;

namespace Concursus.API.Client;

public partial class FormHelper
{
    public async Task<MetadataMigrationRunModel> MetadataMigrationRunCreateAsync(
        string sourceEnvironment,
        string targetEnvironment,
        string sourceServerName,
        string sourceDatabaseName,
        string targetServerName,
        string targetDatabaseName,
        bool isValidateOnly,
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationRunCreateAsync(
            new MetadataMigrationRunCreateRequest
            {
                SourceEnvironment = sourceEnvironment ?? string.Empty,
                TargetEnvironment = targetEnvironment ?? string.Empty,
                SourceServerName = sourceServerName ?? string.Empty,
                SourceDatabaseName = sourceDatabaseName ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                IsValidateOnly = isValidateOnly
            },
            cancellationToken: cancellationToken);

        return MapRun(reply.Run);
    }

    public async Task<List<MetadataMigrationRunModel>> MetadataMigrationRunsAsync(
        int top = 50,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationRunsAsync(
            new MetadataMigrationRunsRequest
            {
                Top = top,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Runs.Select(MapRun).ToList();
    }

    public async Task<MetadataMigrationRunModel> MetadataMigrationRunGetAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationRunGetAsync(
            new MetadataMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return MapRun(reply.Run);
    }

    public async Task<List<MetadataMigrationTableCountModel>> MetadataMigrationStageAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationStageAsync(
            new MetadataMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken, deadline: DateTime.UtcNow.AddMinutes(45));

        return reply.StagedCounts.Select(MapTableCount).ToList();
    }

    public async Task<List<MetadataMigrationValidationIssueModel>> MetadataMigrationValidateAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationValidateAsync(
            new MetadataMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.ValidationIssues.Select(MapValidationIssue).ToList();
    }

    public async Task<List<MetadataMigrationIdentityMapModel>> MetadataMigrationBuildIdentityMapAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationBuildIdentityMapAsync(
            new MetadataMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Rows.Select(MapIdentityMap).ToList();
    }

    public async Task<string> MetadataMigrationApplyAsync(
        Guid runGuid,
        bool forceApply,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationApplyAsync(
            new MetadataMigrationApplyRequest
            {
                RunGuid = runGuid.ToString(),
                ForceApply = forceApply,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                ApplySelectedOnly = false
            },
            cancellationToken: cancellationToken);

        return reply.Message ?? string.Empty;
    }

    public async Task<string> MetadataMigrationApplySelectedAsync(
        Guid runGuid,
        bool forceApply,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationApplyAsync(
            new MetadataMigrationApplyRequest
            {
                RunGuid = runGuid.ToString(),
                ForceApply = forceApply,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                ApplySelectedOnly = true
            },
            cancellationToken: cancellationToken);

        return reply.Message ?? string.Empty;
    }

    public async Task<MetadataMigrationSelectionResultModel> MetadataMigrationSelectionClearAsync(
        Guid runGuid,
        string schemaName = "",
        string tableName = "",
        string differenceType = "",
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationSelectionClearAsync(
            new MetadataMigrationSelectionClearRequest
            {
                RunGuid = runGuid.ToString(),
                SchemaName = schemaName ?? string.Empty,
                TableName = tableName ?? string.Empty,
                DifferenceType = differenceType ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return new MetadataMigrationSelectionResultModel
        {
            SelectedCount = reply.SelectedCount,
            Message = reply.Message ?? string.Empty
        };
    }

    public async Task<MetadataMigrationSelectionResultModel> MetadataMigrationSelectionUpsertAsync(
        Guid runGuid,
        IReadOnlyCollection<MetadataMigrationSelectionItemModel> items,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var request = new MetadataMigrationSelectionUpsertRequest
        {
            RunGuid = runGuid.ToString(),
            TargetServerName = targetServerName ?? string.Empty,
            TargetDatabaseName = targetDatabaseName ?? string.Empty
        };

        foreach (var item in items ?? Array.Empty<MetadataMigrationSelectionItemModel>())
        {
            request.Items.Add(new MetadataMigrationSelectionItem
            {
                SchemaName = item.SchemaName ?? string.Empty,
                TableName = item.TableName ?? string.Empty,
                SourceRowGuid = item.SourceRowGuid.ToString(),
                DifferenceType = item.DifferenceType ?? string.Empty,
                IsSelected = item.IsSelected
            });
        }

        var reply = await _coreClient.MetadataMigrationSelectionUpsertAsync(request, cancellationToken: cancellationToken);

        return new MetadataMigrationSelectionResultModel
        {
            SelectedCount = reply.SelectedCount,
            Message = reply.Message ?? string.Empty
        };
    }


    public async Task<MetadataMigrationIgnoreResultModel> MetadataMigrationIgnoreUpsertAsync(
        Guid runGuid,
        string schemaName,
        string tableName,
        Guid sourceRowGuid,
        bool isIgnored,
        string reason = "",
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationIgnoreUpsertAsync(
            new MetadataMigrationIgnoreUpsertRequest
            {
                RunGuid = runGuid.ToString(),
                SchemaName = schemaName ?? string.Empty,
                TableName = tableName ?? string.Empty,
                SourceRowGuid = sourceRowGuid.ToString(),
                IsIgnored = isIgnored,
                Reason = reason ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return new MetadataMigrationIgnoreResultModel
        {
            IgnoredCount = reply.IgnoredCount,
            Message = reply.Message ?? string.Empty
        };
    }

    public async Task<List<MetadataMigrationIgnoredRecordModel>> MetadataMigrationIgnoredRecordsAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        bool includeInactive = false,
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationIgnoredRecordsAsync(
            new MetadataMigrationIgnoredRecordsRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                IncludeInactive = includeInactive
            },
            cancellationToken: cancellationToken);

        return reply.Records.Select(MapIgnoredRecord).ToList();
    }

    public async Task<MetadataMigrationDashboardModel> MetadataMigrationDashboardAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationDashboardAsync(
            new MetadataMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return new MetadataMigrationDashboardModel
        {
            Run = MapRun(reply.Run),
            FailCount = reply.FailCount,
            WarnCount = reply.WarnCount,
            InfoCount = reply.InfoCount,
            InsertCount = reply.InsertCount,
            UpdateCount = reply.UpdateCount,
            NoChangeCount = reply.NoChangeCount,
            MapRows = reply.MapRows,
            MissingTargetRows = reply.MissingTargetRows,
            SelectedCount = reply.SelectedCount,
            IgnoredCount = reply.IgnoredCount,
            StagedCounts = reply.StagedCounts.Select(MapTableCount).ToList(),
            ValidationIssues = reply.ValidationIssues.Select(MapValidationIssue).ToList(),
            IdentityMap = reply.IdentityMap.Select(MapIdentityMap).ToList(),
            ExecutionLog = reply.ExecutionLog.Select(MapExecutionLog).ToList()
        };
    }

    public async Task<List<MetadataMigrationStagedRowModel>> MetadataMigrationStagedRowsAsync(
        Guid runGuid,
        string schemaName,
        string tableName,
        string differenceType,
        string targetServerName = "",
        string targetDatabaseName = "",
        bool includeIgnored = false,
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationStagedRowsAsync(
            new MetadataMigrationRowsRequest
            {
                RunGuid = runGuid.ToString(),
                SchemaName = schemaName ?? string.Empty,
                TableName = tableName ?? string.Empty,
                DifferenceType = differenceType ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                IncludeIgnored = includeIgnored
            },
            cancellationToken: cancellationToken);

        return reply.Rows.Select(x => new MetadataMigrationStagedRowModel
        {
            SchemaName = x.SchemaName,
            TableName = x.TableName,
            SourceRowGuid = Guid.TryParse(x.SourceRowGuid, out var sourceGuid) ? sourceGuid : Guid.Empty,
            SourceRowId = x.SourceRowId,
            DifferenceType = x.DifferenceType,
            SourcePayloadJson = x.SourcePayloadJson,
            TargetPayloadJson = x.TargetPayloadJson,
            SourceValues = x.SourceValues.ToDictionary(k => k.Key, v => v.Value),
            TargetValues = x.TargetValues.ToDictionary(k => k.Key, v => v.Value),
            IsSelected = x.IsSelected,
            IsIgnored = x.IsIgnored,
            IgnoreReason = x.IgnoreReason,
            IgnoredOnUtcText = x.IgnoredOnUtc
        }).ToList();
    }

    public async Task<List<MetadataMigrationDiffRowModel>> MetadataMigrationDiffAsync(
        Guid runGuid,
        string schemaName,
        string tableName,
        string differenceType,
        string targetServerName = "",
        string targetDatabaseName = "",
        bool includeIgnored = false,
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationDiffAsync(
            new MetadataMigrationRowsRequest
            {
                RunGuid = runGuid.ToString(),
                SchemaName = schemaName ?? string.Empty,
                TableName = tableName ?? string.Empty,
                DifferenceType = differenceType ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                IncludeIgnored = includeIgnored
            },
            cancellationToken: cancellationToken);

        var result = new List<MetadataMigrationDiffRowModel>(reply.Rows.Count);
        foreach (var row in reply.Rows)
        {
            var model = new MetadataMigrationDiffRowModel
            {
                SchemaName = row.SchemaName,
                TableName = row.TableName,
                SourceRowGuid = Guid.TryParse(row.SourceRowGuid, out var parsedGuid) ? parsedGuid : Guid.Empty,
                DifferenceType = row.DifferenceType,
                IsSelected = row.IsSelected,
                IsIgnored = row.IsIgnored,
                IgnoreReason = row.IgnoreReason,
                IgnoredOnUtcText = row.IgnoredOnUtc,
                SourceValues = row.SourceValues.ToDictionary(k => k.Key, v => v.Value),
                TargetValues = row.TargetValues.ToDictionary(k => k.Key, v => v.Value)
            };

            model.DifferingColumns.AddRange(row.DifferingColumns);
            result.Add(model);
        }

        return result;
    }

    private static MetadataMigrationRunModel MapRun(MetadataMigrationRunSummary? run)
    {
        if (run is null)
        {
            return new MetadataMigrationRunModel();
        }

        return new MetadataMigrationRunModel
        {
            RunGuid = Guid.TryParse(run.RunGuid, out var runGuid) ? runGuid : Guid.Empty,
            SourceEnvironment = run.SourceEnvironment,
            TargetEnvironment = run.TargetEnvironment,
            SourceServerName = run.SourceServerName,
            SourceDatabaseName = run.SourceDatabaseName,
            TargetServerName = run.TargetServerName,
            TargetDatabaseName = run.TargetDatabaseName,
            RunStatus = run.RunStatus,
            IsValidateOnly = run.IsValidateOnly,
            CreatedOnUtcText = run.CreatedOnUtc,
            ValidatedOnUtcText = run.ValidatedOnUtc,
            AppliedOnUtcText = run.AppliedOnUtc,
            SummaryJson = run.SummaryJson
        };
    }

    private static MetadataMigrationTableCountModel MapTableCount(MetadataMigrationTableCount row) => new()
    {
        SchemaName = row.SchemaName,
        TableName = row.TableName,
        DifferenceType = row.DifferenceType,
        Count = row.Count
    };

    private static MetadataMigrationValidationIssueModel MapValidationIssue(MetadataMigrationValidationIssue row) => new()
    {
        Guid = Guid.TryParse(row.Guid, out var guid) ? guid : Guid.Empty,
        RegistryGuid = Guid.TryParse(row.RegistryGuid, out var registryGuid) ? registryGuid : Guid.Empty,
        SourceRowGuid = Guid.TryParse(row.SourceRowGuid, out var sourceGuid) ? sourceGuid : Guid.Empty,
        SchemaName = row.SchemaName,
        TableName = row.TableName,
        Severity = row.Severity,
        IssueCode = row.IssueCode,
        IssueMessage = row.IssueMessage,
        DetailsJson = row.DetailsJson
    };

    private static MetadataMigrationIdentityMapModel MapIdentityMap(MetadataMigrationIdentityMapRow row) => new()
    {
        SchemaName = row.SchemaName,
        TableName = row.TableName,
        MapRows = row.MapRows,
        MissingTargetRows = row.MissingTargetRows
    };

    private static MetadataMigrationExecutionLogItemModel MapExecutionLog(MetadataMigrationExecutionLogItem row) => new()
    {
        StepName = row.StepName,
        StepStatus = row.StepStatus,
        Message = row.Message,
        DetailsJson = row.DetailsJson,
        CreatedOnUtcText = row.CreatedOnUtc
    };

    private static MetadataMigrationIgnoredRecordModel MapIgnoredRecord(MetadataMigrationIgnoredRecord row) => new()
    {
        Guid = Guid.TryParse(row.Guid, out var guid) ? guid : Guid.Empty,
        DatabaseName = row.DatabaseName,
        SchemaName = row.SchemaName,
        TableName = row.TableName,
        SourceRowGuid = Guid.TryParse(row.SourceRowGuid, out var sourceGuid) ? sourceGuid : Guid.Empty,
        StableRecordKey = row.StableRecordKey,
        Reason = row.Reason,
        IgnoredByUserId = row.IgnoredByUserId,
        IgnoredOnUtcText = row.IgnoredOnUtc,
        UnignoredOnUtcText = row.UnignoredOnUtc,
        RowStatus = row.RowStatus
    };

}
