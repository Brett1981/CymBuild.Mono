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
        CancellationToken cancellationToken = default)
    {
        var request = new OnboardingMigrationStageRequest
        {
            SourceDatabase = sourceDatabase ?? string.Empty,
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

    public async Task<List<OnboardingMigrationLookupItemModel>> OnboardingMigrationBusinessUnitGroupsAsync(
    string sourceDatabase,
    CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationBusinessUnitGroupsAsync(
            new OnboardingMigrationLookupRequest { SourceDatabase = sourceDatabase ?? string.Empty },
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
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationRunsAsync(
            new OnboardingMigrationLookupRequest { SourceDatabase = sourceDatabase ?? string.Empty },
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
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationValidateAsync(
            new OnboardingMigrationRunRequest { RunGuid = runGuid.ToString() },
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
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationApplyAsync(
            new OnboardingMigrationApplyRequest
            {
                RunGuid = runGuid.ToString(),
                AllowWarnings = allowWarnings,
                PreviewOnly = previewOnly
            },
            cancellationToken: cancellationToken);

        return reply.Message ?? string.Empty;
    }

    public async Task<OnboardingMigrationReportModel> OnboardingMigrationReportAsync(
        Guid runGuid,
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationReportAsync(
            new OnboardingMigrationRunRequest { RunGuid = runGuid.ToString() },
            cancellationToken: cancellationToken);

        var result = new OnboardingMigrationReportModel
        {
            RunGuid = Guid.TryParse(reply.RunSummary?.RunGuid, out var parsedRunGuid) ? parsedRunGuid : Guid.Empty,
            SourceDatabase = reply.RunSummary?.SourceDatabase ?? string.Empty,
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
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationStagedDataAsync(
            new OnboardingMigrationStagedDataRequest
            {
                RunGuid = runGuid.ToString(),
                EntityName = entityName ?? string.Empty
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
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationDiffAsync(
            new OnboardingMigrationDiffRequest
            {
                RunGuid = runGuid.ToString(),
                EntityName = entityName ?? string.Empty
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

    public async Task<OnboardingMigrationAuditDashboardModel> OnboardingMigrationAuditDashboardAsync(
        Guid runGuid,
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.OnboardingMigrationAuditDashboardAsync(
            new OnboardingMigrationAuditDashboardRequest
            {
                RunGuid = runGuid.ToString()
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
}