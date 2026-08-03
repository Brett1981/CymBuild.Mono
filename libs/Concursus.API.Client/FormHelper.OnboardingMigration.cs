using Concursus.API.Client.Models.OnboardingMigration;
using Concursus.API.Core;
using System.Linq;

namespace Concursus.API.Client;

public partial class FormHelper
{
    public async Task<OnboardingMigrationStageResultModel> OnboardingMigrationStageAsync(
        string sourceDatabase,
        Guid businessUnitGroupGuid,
        Guid? runGuid,
        string notes,
        string sourceServerName = "",
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var request = new OnboardingMigrationStageRequest
        {
            SourceDatabase = sourceDatabase ?? string.Empty,
            SourceServerName = sourceServerName ?? string.Empty,
            TargetServerName = targetServerName ?? string.Empty,
            TargetDatabaseName = targetDatabaseName ?? string.Empty,
            BusinessUnitGroupGuid = businessUnitGroupGuid.ToString(),
            RunGuid = runGuid?.ToString() ?? string.Empty,
            Notes = notes ?? string.Empty
        };

        var reply = await _coreClient.OnboardingMigrationStageAsync(request, cancellationToken: cancellationToken);

        return new OnboardingMigrationStageResultModel
        {
            RunGuid = Guid.TryParse(reply.RunGuid, out var parsedRunGuid) ? parsedRunGuid : Guid.Empty,
            GroupCount = reply.GroupCount,
            IdentityCount = reply.IdentityCount,
            UserGroupCount = reply.UserGroupCount,
            WorkflowNotificationGroupCount = reply.WorkflowNotificationGroupCount,
            JobTypeCount = reply.JobTypeCount,
            ActivityTypeCount = reply.ActivityTypeCount,
            MilestoneTypeCount = reply.MilestoneTypeCount,
            ProductCount = reply.ProductCount,
            JobTypeActivityTypeCount = reply.JobTypeActivityTypeCount,
            JobTypeMilestoneTemplateCount = reply.JobTypeMilestoneTemplateCount,
            ProductJobActivityCount = reply.ProductJobActivityCount
        };
    }


    public async Task<OnboardingMigrationReportModel> OnboardingMigrationRunReserveAsync(
        Guid? runGuid,
        string sourceDatabase,
        Guid businessUnitGroupGuid,
        string notes,
        string sourceServerName = "",
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationRunReserveAsync(
            new OnboardingMigrationRunReserveRequest
            {
                RunGuid = runGuid?.ToString() ?? string.Empty,
                SourceDatabase = sourceDatabase ?? string.Empty,
                SourceServerName = sourceServerName ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                BusinessUnitGroupGuid = businessUnitGroupGuid.ToString(),
                Notes = notes ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return new OnboardingMigrationReportModel
        {
            RunGuid = Guid.TryParse(reply.RunSummary?.RunGuid, out var parsedRunGuid) ? parsedRunGuid : Guid.Empty,
            SourceDatabase = reply.RunSummary?.SourceDatabase ?? string.Empty,
            SourceServerName = reply.RunSummary?.SourceServerName ?? string.Empty,
            TargetServerName = reply.RunSummary?.TargetServerName ?? string.Empty,
            TargetDatabaseName = reply.RunSummary?.TargetDatabaseName ?? string.Empty,
            SourceBusinessUnitGroupGuid = Guid.TryParse(reply.RunSummary?.SourceBusinessUnitGroupGuid, out var parsedBuGuid) ? parsedBuGuid : Guid.Empty,
            Notes = reply.RunSummary?.Notes ?? string.Empty,
            CreatedUtcText = reply.RunSummary?.CreatedUtc ?? string.Empty,
            CreatedBy = reply.RunSummary?.CreatedBy ?? string.Empty
        };
    }

    public async Task<List<OnboardingMigrationLookupItemModel>> OnboardingMigrationBusinessUnitGroupsAsync(
        string sourceDatabase,
        string sourceServerName = "",
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationBusinessUnitGroupsAsync(
            new OnboardingMigrationLookupRequest
            {
                SourceDatabase = sourceDatabase ?? string.Empty,
                SourceServerName = sourceServerName ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Items.Select(x => new OnboardingMigrationLookupItemModel
        {
            Guid = Guid.TryParse(x.Guid, out var g) ? g : Guid.Empty,
            Name = x.Name,
            Code = x.Code,
            Description = x.Description
        }).ToList();
    }

    public async Task<List<OnboardingMigrationLookupItemModel>> OnboardingMigrationRunsAsync(
        string sourceDatabase,
        string sourceServerName = "",
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationRunsAsync(
            new OnboardingMigrationLookupRequest
            {
                SourceDatabase = sourceDatabase ?? string.Empty,
                SourceServerName = sourceServerName ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Items.Select(x => new OnboardingMigrationLookupItemModel
        {
            Guid = Guid.TryParse(x.Guid, out var g) ? g : Guid.Empty,
            Name = x.Name,
            Code = x.Code,
            Description = x.Description
        }).ToList();
    }

    public async Task<List<OnboardingMigrationValidationIssueModel>> OnboardingMigrationValidateAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationValidateAsync(
            new OnboardingMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.ValidationIssues.Select(x => new OnboardingMigrationValidationIssueModel
        {
            EntityName = x.EntityName,
            StageTable = x.StageTable,
            StageGuid = Guid.TryParse(x.StageGuid, out var parsedGuid) ? parsedGuid : Guid.Empty,
            Severity = x.Severity,
            IssueCode = x.IssueCode,
            IssueMessage = x.IssueMessage
        }).ToList();
    }

    public async Task<string> OnboardingMigrationApplyAsync(
        Guid runGuid,
        bool allowWarnings,
        bool previewOnly,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationApplyAsync(
            new OnboardingMigrationApplyRequest
            {
                RunGuid = runGuid.ToString(),
                AllowWarnings = allowWarnings,
                PreviewOnly = previewOnly,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Message ?? string.Empty;
    }

    public async Task<OnboardingMigrationReportModel> OnboardingMigrationReportAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationReportAsync(
            new OnboardingMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        var result = new OnboardingMigrationReportModel
        {
            RunGuid = Guid.TryParse(reply.RunSummary?.RunGuid, out var parsedRunGuid) ? parsedRunGuid : Guid.Empty,
            SourceDatabase = reply.RunSummary?.SourceDatabase ?? string.Empty,
            SourceServerName = reply.RunSummary?.SourceServerName ?? string.Empty,
            TargetServerName = reply.RunSummary?.TargetServerName ?? string.Empty,
            TargetDatabaseName = reply.RunSummary?.TargetDatabaseName ?? string.Empty,
            SourceBusinessUnitGroupGuid = Guid.TryParse(reply.RunSummary?.SourceBusinessUnitGroupGuid, out var parsedBuGuid) ? parsedBuGuid : Guid.Empty,
            Notes = reply.RunSummary?.Notes ?? string.Empty,
            CreatedUtcText = reply.RunSummary?.CreatedUtc ?? string.Empty,
            CreatedBy = reply.RunSummary?.CreatedBy ?? string.Empty
        };

        result.StagedCounts.AddRange(reply.StagedCounts.Select(x => new OnboardingMigrationEntityCountModel
        {
            EntityName = x.EntityName,
            Count = x.Count
        }));

        result.ValidationIssues.AddRange(reply.ValidationIssues.Select(x => new OnboardingMigrationValidationIssueModel
        {
            EntityName = x.EntityName,
            StageTable = x.StageTable,
            StageGuid = Guid.TryParse(x.StageGuid, out var parsedGuid) ? parsedGuid : Guid.Empty,
            Severity = x.Severity,
            IssueCode = x.IssueCode,
            IssueMessage = x.IssueMessage
        }));

        result.ExecutionLog.AddRange(reply.ExecutionLog.Select(x => new OnboardingMigrationExecutionLogItemModel
        {
            StepName = x.StepName,
            EntityName = x.EntityName,
            ActionName = x.ActionName,
            AffectedCount = x.AffectedCount,
            Details = x.Details,
            LoggedUtcText = x.LoggedUtc
        }));

        return result;
    }

    public async Task<List<OnboardingMigrationStagedRowModel>> OnboardingMigrationStagedDataAsync(
        Guid runGuid,
        string entityName,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationStagedDataAsync(
            new OnboardingMigrationStagedDataRequest
            {
                RunGuid = runGuid.ToString(),
                EntityName = entityName ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Rows.Select(x => new OnboardingMigrationStagedRowModel
        {
            EntityName = x.EntityName,
            RowGuid = Guid.TryParse(x.RowGuid, out var parsedGuid) ? parsedGuid : Guid.Empty,
            Values = x.Values.ToDictionary(k => k.Key, v => v.Value)
        }).ToList();
    }

    public async Task<List<OnboardingMigrationDiffRowModel>> OnboardingMigrationDiffAsync(
        Guid runGuid,
        string entityName,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationDiffAsync(
            new OnboardingMigrationDiffRequest
            {
                RunGuid = runGuid.ToString(),
                EntityName = entityName ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        var result = new List<OnboardingMigrationDiffRowModel>(reply.Rows.Count);

        foreach (var row in reply.Rows)
        {
            var model = new OnboardingMigrationDiffRowModel
            {
                EntityName = row.EntityName,
                RowGuid = Guid.TryParse(row.RowGuid, out var parsedGuid) ? parsedGuid : Guid.Empty,
                DiffType = row.DiffType,
                SourceValues = row.SourceValues.ToDictionary(k => k.Key, v => v.Value),
                TargetValues = row.TargetValues.ToDictionary(k => k.Key, v => v.Value)
            };

            model.DifferingColumns.AddRange(row.DifferingColumns);
            result.Add(model);
        }

        return result;
    }


    public async Task<List<OnboardingMigrationStageSelectionModel>> OnboardingMigrationStageSelectionListAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationStageSelectionListAsync(
            new OnboardingMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Selections.Select(x => new OnboardingMigrationStageSelectionModel
        {
            EntityName = x.EntityName,
            RowGuid = Guid.TryParse(x.RowGuid, out var rowGuid) ? rowGuid : Guid.Empty,
            SelectedOnUtcText = x.SelectedOnUtc
        }).ToList();
    }

    public async Task<List<OnboardingMigrationStageSelectionModel>> OnboardingMigrationStageSelectionSaveAsync(
        Guid runGuid,
        IEnumerable<OnboardingMigrationStageSelectionModel> selections,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var request = new OnboardingMigrationStageSelectionSaveRequest
        {
            RunGuid = runGuid.ToString(),
            TargetServerName = targetServerName ?? string.Empty,
            TargetDatabaseName = targetDatabaseName ?? string.Empty
        };

        foreach (var selection in selections ?? Enumerable.Empty<OnboardingMigrationStageSelectionModel>())
        {
            if (selection.RowGuid == Guid.Empty || string.IsNullOrWhiteSpace(selection.EntityName))
            {
                continue;
            }

            request.Selections.Add(new OnboardingMigrationStageSelectionItem
            {
                EntityName = selection.EntityName,
                RowGuid = selection.RowGuid.ToString()
            });
        }

        var reply = await _coreClient.OnboardingMigrationStageSelectionSaveAsync(
            request,
            cancellationToken: cancellationToken);

        return reply.Selections.Select(x => new OnboardingMigrationStageSelectionModel
        {
            EntityName = x.EntityName,
            RowGuid = Guid.TryParse(x.RowGuid, out var rowGuid) ? rowGuid : Guid.Empty,
            SelectedOnUtcText = x.SelectedOnUtc
        }).ToList();
    }

    public async Task<OnboardingMigrationAuditDashboardModel> OnboardingMigrationAuditDashboardAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationAuditDashboardAsync(
            new OnboardingMigrationAuditDashboardRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        var result = new OnboardingMigrationAuditDashboardModel
        {
            StagedEntityCount = reply.Summary?.StagedEntityCount ?? 0,
            TotalStagedRows = reply.Summary?.TotalStagedRows ?? 0,
            ValidationErrorCount = reply.Summary?.ValidationErrorCount ?? 0,
            ValidationWarningCount = reply.Summary?.ValidationWarningCount ?? 0,
            ExecutionLogCount = reply.Summary?.ExecutionLogCount ?? 0,
            InsertedRowCount = reply.Summary?.InsertedRowCount ?? 0,
            UpdatedRowCount = reply.Summary?.UpdatedRowCount ?? 0
        };

        result.StagedCounts.AddRange(reply.StagedCounts.Select(x => new OnboardingMigrationEntityCountModel
        {
            EntityName = x.EntityName,
            Count = x.Count
        }));

        result.ValidationIssues.AddRange(reply.ValidationIssues.Select(x => new OnboardingMigrationValidationIssueModel
        {
            EntityName = x.EntityName,
            StageTable = x.StageTable,
            StageGuid = Guid.TryParse(x.StageGuid, out var parsedGuid) ? parsedGuid : Guid.Empty,
            Severity = x.Severity,
            IssueCode = x.IssueCode,
            IssueMessage = x.IssueMessage
        }));

        result.ExecutionLog.AddRange(reply.ExecutionLog.Select(x => new OnboardingMigrationExecutionLogItemModel
        {
            StepName = x.StepName,
            EntityName = x.EntityName,
            ActionName = x.ActionName,
            AffectedCount = x.AffectedCount,
            Details = x.Details,
            LoggedUtcText = x.LoggedUtc
        }));

        return result;
    }

    public async Task<List<OnboardingMigrationEntityScopeModel>> OnboardingMigrationEntityScopeListAsync(
        string searchText = "",
        bool includeInactive = false,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationEntityScopeListAsync(
            new OnboardingMigrationEntityScopeRequest
            {
                SearchText = searchText ?? string.Empty,
                IncludeInactive = includeInactive,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Items.Select(MapEntityScope).ToList();
    }

    public async Task<List<OnboardingMigrationEntitySelectionModel>> OnboardingMigrationRunEntitySelectionDefaultAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationRunEntitySelectionDefaultAsync(
            new OnboardingMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Items.Select(MapEntitySelection).ToList();
    }

    public async Task<List<OnboardingMigrationEntitySelectionModel>> OnboardingMigrationRunEntitySelectionListAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationRunEntitySelectionListAsync(
            new OnboardingMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Items.Select(MapEntitySelection).ToList();
    }

    public async Task<List<OnboardingMigrationEntitySelectionModel>> OnboardingMigrationRunEntitySelectionSaveAsync(
        Guid runGuid,
        IEnumerable<OnboardingMigrationEntitySelectionModel> selections,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var request = new OnboardingMigrationEntitySelectionSaveRequest
        {
            RunGuid = runGuid.ToString(),
            TargetServerName = targetServerName ?? string.Empty,
            TargetDatabaseName = targetDatabaseName ?? string.Empty
        };

        foreach (var selection in selections ?? Enumerable.Empty<OnboardingMigrationEntitySelectionModel>())
        {
            request.Selections.Add(new OnboardingMigrationEntitySelectionSaveItem
            {
                EntityCode = selection.EntityCode ?? string.Empty,
                IsSelected = selection.IsSelected
            });
        }

        var reply = await _coreClient.OnboardingMigrationRunEntitySelectionSaveAsync(
            request,
            cancellationToken: cancellationToken);

        return reply.Items.Select(MapEntitySelection).ToList();
    }

    private static OnboardingMigrationEntityScopeModel MapEntityScope(OnboardingMigrationEntityScopeItem item) =>
        new()
        {
            EntityScopeGuid = Guid.TryParse(item.EntityScopeGuid, out var entityScopeGuid) ? entityScopeGuid : Guid.Empty,
            Code = item.Code,
            Name = item.Name,
            Description = item.Description,
            StageTableName = item.StageTableName,
            ScopeCategory = item.ScopeCategory,
            ScopeType = item.ScopeType,
            IsImplemented = item.IsImplemented,
            IsSupportData = item.IsSupportData,
            HandlerKey = item.HandlerKey,
            PrimaryEntityTypeGuid = Guid.TryParse(item.PrimaryEntityTypeGuid, out var primaryEntityTypeGuid) ? primaryEntityTypeGuid : null,
            SourceSchemaName = item.SourceSchemaName,
            SourceTableName = item.SourceTableName,
            DisplayOrder = item.DisplayOrder,
            DefaultSelected = item.DefaultSelected,
            CanDeselect = item.CanDeselect,
            IsRequired = item.IsRequired,
            RequiredDependencyCodes = item.RequiredDependencyCodes,
            RowStatus = item.RowStatus
        };

    private static OnboardingMigrationEntitySelectionModel MapEntitySelection(OnboardingMigrationEntitySelectionItem item) =>
        new()
        {
            EntityScopeGuid = Guid.TryParse(item.EntityScopeGuid, out var entityScopeGuid) ? entityScopeGuid : Guid.Empty,
            SelectionGuid = Guid.TryParse(item.SelectionGuid, out var selectionGuid) ? selectionGuid : Guid.Empty,
            EntityCode = item.EntityCode,
            EntityName = item.EntityName,
            Description = item.Description,
            StageTableName = item.StageTableName,
            ScopeCategory = item.ScopeCategory,
            ScopeType = item.ScopeType,
            IsImplemented = item.IsImplemented,
            IsSupportData = item.IsSupportData,
            HandlerKey = item.HandlerKey,
            PrimaryEntityTypeGuid = Guid.TryParse(item.PrimaryEntityTypeGuid, out var primaryEntityTypeGuid) ? primaryEntityTypeGuid : null,
            SourceSchemaName = item.SourceSchemaName,
            SourceTableName = item.SourceTableName,
            DisplayOrder = item.DisplayOrder,
            IsSelected = item.IsSelected,
            DefaultSelected = item.DefaultSelected,
            CanDeselect = item.CanDeselect,
            IsRequired = item.IsRequired,
            RequiredDependencyCodes = item.RequiredDependencyCodes,
            SelectionSource = item.SelectionSource,
            SelectedOnUtc = item.SelectedOnUtc
        };
}
