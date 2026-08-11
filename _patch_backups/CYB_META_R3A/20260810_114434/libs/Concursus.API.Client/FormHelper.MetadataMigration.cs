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

    public async Task<string> MetadataMigrationIdentityMapReviewSetAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationIdentityMapReviewSetAsync(
            new MetadataMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Message ?? string.Empty;
    }


    public async Task<MetadataMigrationIdentityMapDetailsResultModel> MetadataMigrationIdentityMapDetailsAsync(
        Guid runGuid,
        string schemaName = "",
        string tableName = "",
        string targetServerName = "",
        string targetDatabaseName = "",
        bool includeIgnored = true,
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationIdentityMapDetailsAsync(
            new MetadataMigrationIdentityMapDetailsRequest
            {
                RunGuid = runGuid.ToString(),
                SchemaName = schemaName ?? string.Empty,
                TableName = tableName ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                IncludeIgnored = includeIgnored
            },
            cancellationToken: cancellationToken);

        return new MetadataMigrationIdentityMapDetailsResultModel
        {
            UnresolvedCount = reply.UnresolvedCount,
            IgnoredCount = reply.IgnoredCount,
            ResolvedCount = reply.ResolvedCount,
            Rows = reply.Rows.Select(MapIdentityMapDetail).ToList()
        };
    }

    public async Task<MetadataMigrationIdentityMapIssueResultModel> MetadataMigrationIdentityMapIssueUpsertAsync(
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
        var reply = await _coreClient.MetadataMigrationIdentityMapIssueUpsertAsync(
            new MetadataMigrationIdentityMapIssueUpsertRequest
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

        return new MetadataMigrationIdentityMapIssueResultModel
        {
            UnresolvedCount = reply.UnresolvedCount,
            IgnoredCount = reply.IgnoredCount,
            Message = reply.Message ?? string.Empty
        };
    }

    public async Task<MetadataMigrationIdentityMapCandidatesResultModel> MetadataMigrationIdentityMapCandidatesAsync(
        Guid runGuid,
        string schemaName,
        string tableName,
        Guid sourceRowGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        string searchText = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationIdentityMapCandidatesAsync(
            new MetadataMigrationIdentityMapCandidatesRequest
            {
                RunGuid = runGuid.ToString(),
                SchemaName = schemaName ?? string.Empty,
                TableName = tableName ?? string.Empty,
                SourceRowGuid = sourceRowGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                SearchText = searchText ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return new MetadataMigrationIdentityMapCandidatesResultModel
        {
            SourceDisplayName = reply.SourceDisplayName ?? string.Empty,
            SourcePayloadJson = reply.SourcePayloadJson ?? string.Empty,
            Rows = reply.Rows.Select(MapIdentityMapCandidate).ToList()
        };
    }

    public async Task<MetadataMigrationIdentityMapIssueResultModel> MetadataMigrationIdentityMapOverrideUpsertAsync(
        Guid runGuid,
        string schemaName,
        string tableName,
        Guid sourceRowGuid,
        Guid targetRowGuid,
        bool isActive,
        string reason = "",
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationIdentityMapOverrideUpsertAsync(
            new MetadataMigrationIdentityMapOverrideUpsertRequest
            {
                RunGuid = runGuid.ToString(),
                SchemaName = schemaName ?? string.Empty,
                TableName = tableName ?? string.Empty,
                SourceRowGuid = sourceRowGuid.ToString(),
                TargetRowGuid = targetRowGuid == Guid.Empty ? string.Empty : targetRowGuid.ToString(),
                IsActive = isActive,
                Reason = reason ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return new MetadataMigrationIdentityMapIssueResultModel
        {
            UnresolvedCount = reply.UnresolvedCount,
            IgnoredCount = reply.IgnoredCount,
            Message = reply.Message ?? string.Empty
        };
    }

    public async Task<MetadataMigrationApplyPreviewModel> MetadataMigrationApplyPreviewAsync(
        Guid runGuid,
        bool applySelectedOnly,
        string targetServerName = "",
        string targetDatabaseName = "",
        bool includeIgnored = true,
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationApplyPreviewAsync(
            new MetadataMigrationApplyPreviewRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                ApplySelectedOnly = applySelectedOnly,
                IncludeIgnored = includeIgnored
            },
            cancellationToken: cancellationToken);

        return new MetadataMigrationApplyPreviewModel
        {
            ApplySelectedOnly = reply.ApplySelectedOnly,
            ApplyCount = reply.ApplyCount,
            SkipCount = reply.SkipCount,
            BlockedCount = reply.BlockedCount,
            IgnoredSkipCount = reply.IgnoredSkipCount,
            RunValidationFailureCount = reply.RunValidationFailureCount,
            Rows = reply.Rows.Select(row => new MetadataMigrationApplyPreviewRowModel
            {
                SchemaName = row.SchemaName ?? string.Empty,
                TableName = row.TableName ?? string.Empty,
                SourceRowGuid = Guid.TryParse(row.SourceRowGuid, out var sourceRowGuid) ? sourceRowGuid : Guid.Empty,
                SourceRowId = row.SourceRowId,
                DifferenceType = row.DifferenceType ?? string.Empty,
                IsSelected = row.IsSelected,
                IsIgnored = row.IsIgnored,
                HasValidationFailure = row.HasValidationFailure,
                ApplyAction = row.ApplyAction ?? string.Empty,
                SkipReason = row.SkipReason ?? string.Empty,
                ChangedColumns = row.ChangedColumns ?? string.Empty,
                RunValidationFailureCount = row.RunValidationFailureCount
            }).ToList()
        };
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

    public async Task<List<MetadataMigrationEntityTypeScopeRowModel>> MetadataMigrationEntityTypeScopeListAsync(
        string serverName,
        string databaseName,
        bool showMetadataOnly = true,
        string searchText = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.MetadataMigrationEntityTypeScopeListAsync(
            new MetadataMigrationEntityTypeScopeRequest
            {
                ServerName = serverName ?? string.Empty,
                DatabaseName = databaseName ?? string.Empty,
                ShowMetadataOnly = showMetadataOnly,
                SearchText = searchText ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Rows.Select(row => new MetadataMigrationEntityTypeScopeRowModel
        {
            EntityTypeGuid = Guid.TryParse(row.EntityTypeGuid, out var entityTypeGuid) ? entityTypeGuid : Guid.Empty,
            Name = row.Name ?? string.Empty,
            RowStatus = row.RowStatus,
            IsMetaData = row.IsMetaData,
            HasDocuments = row.HasDocuments,
            IsRootEntity = row.IsRootEntity,
            IsDeletable = row.IsDeletable,
            HasMainHoBT = row.HasMainHoBT,
            MainHoBTSchemaName = row.MainHoBTSchemaName ?? string.Empty,
            MainHoBTObjectName = row.MainHoBTObjectName ?? string.Empty
        }).ToList();
    }

    public async Task<MetadataMigrationEntityTypeScopeSaveResultModel> MetadataMigrationEntityTypeScopeSaveAsync(
        string serverName,
        string databaseName,
        IReadOnlyCollection<MetadataMigrationEntityTypeScopeUpdateItemModel> items,
        CancellationToken cancellationToken = default)
    {
        var request = new MetadataMigrationEntityTypeScopeSaveRequest
        {
            ServerName = serverName ?? string.Empty,
            DatabaseName = databaseName ?? string.Empty
        };

        foreach (var item in items ?? Array.Empty<MetadataMigrationEntityTypeScopeUpdateItemModel>())
        {
            request.Items.Add(new MetadataMigrationEntityTypeScopeUpdateItem
            {
                EntityTypeGuid = item.EntityTypeGuid.ToString(),
                IsMetaData = item.IsMetaData
            });
        }

        var reply = await _coreClient.MetadataMigrationEntityTypeScopeSaveAsync(request, cancellationToken: cancellationToken);

        return new MetadataMigrationEntityTypeScopeSaveResultModel
        {
            UpdatedCount = reply.UpdatedCount,
            Message = reply.Message ?? string.Empty
        };
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

    private static MetadataMigrationIdentityMapDetailModel MapIdentityMapDetail(MetadataMigrationIdentityMapDetailRow row) => new()
    {
        SchemaName = row.SchemaName ?? string.Empty,
        TableName = row.TableName ?? string.Empty,
        SourceRowGuid = Guid.TryParse(row.SourceRowGuid, out var sourceRowGuid) ? sourceRowGuid : Guid.Empty,
        SourceRowId = row.SourceRowId,
        TargetRowId = row.TargetRowId,
        DifferenceType = row.DifferenceType ?? string.Empty,
        SourceDisplayName = row.SourceDisplayName ?? string.Empty,
        IssueCode = row.IssueCode ?? string.Empty,
        IssueStatus = row.IssueStatus ?? string.Empty,
        Reason = row.Reason ?? string.Empty,
        SuggestedAction = row.SuggestedAction ?? string.Empty,
        IsResolved = row.IsResolved,
        IsIgnoredIssue = row.IsIgnoredIssue,
        IgnoreReason = row.IgnoreReason ?? string.Empty,
        IgnoredOnUtcText = row.IgnoredOnUtc ?? string.Empty,
        SourcePayloadJson = row.SourcePayloadJson ?? string.Empty,
        HasOverride = row.HasOverride,
        OverrideTargetRowGuid = Guid.TryParse(row.OverrideTargetRowGuid, out var overrideGuid) ? overrideGuid : Guid.Empty,
        OverrideTargetDisplayName = row.OverrideTargetDisplayName ?? string.Empty,
        OverrideReason = row.OverrideReason ?? string.Empty
    };

    private static MetadataMigrationIdentityMapCandidateModel MapIdentityMapCandidate(MetadataMigrationIdentityMapCandidateRow row) => new()
    {
        TargetRowGuid = Guid.TryParse(row.TargetRowGuid, out var targetGuid) ? targetGuid : Guid.Empty,
        TargetRowId = row.TargetRowId,
        TargetDisplayName = row.TargetDisplayName ?? string.Empty,
        MatchReason = row.MatchReason ?? string.Empty,
        MatchScore = row.MatchScore,
        TargetPayloadJson = row.TargetPayloadJson ?? string.Empty
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
