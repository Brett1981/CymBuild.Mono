using Concursus.API.Client.Models.SchemaMigration;
using Concursus.API.Core;
using System.Linq;

namespace Concursus.API.Client;

public partial class FormHelper
{
    public async Task<SchemaMigrationRunModel> SchemaMigrationRunCreateAsync(
        string sourceEnvironment,
        string targetEnvironment,
        string sourceServerName,
        string sourceDatabaseName,
        string targetServerName,
        string targetDatabaseName,
        string jiraReference,
        string releaseReference,
        string notes,
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationRunCreateAsync(
            new SchemaMigrationRunCreateRequest
            {
                SourceEnvironment = sourceEnvironment ?? string.Empty,
                TargetEnvironment = targetEnvironment ?? string.Empty,
                SourceServerName = sourceServerName ?? string.Empty,
                SourceDatabaseName = sourceDatabaseName ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                JiraReference = jiraReference ?? string.Empty,
                ReleaseReference = releaseReference ?? string.Empty,
                Notes = notes ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return MapSchemaRun(reply.Run);
    }

    public async Task<List<SchemaMigrationRunModel>> SchemaMigrationRunsAsync(
        int top = 50,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationRunsAsync(
            new SchemaMigrationRunsRequest
            {
                Top = top,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Runs.Select(MapSchemaRun).ToList();
    }

    public async Task<SchemaMigrationRunModel> SchemaMigrationRunGetAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationRunGetAsync(
            new SchemaMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return MapSchemaRun(reply.Run);
    }

    public async Task<SchemaMigrationDashboardModel> SchemaMigrationCompareAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationCompareAsync(
            new SchemaMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken,
            deadline: DateTime.UtcNow.AddMinutes(45));

        return MapSchemaDashboard(reply.Dashboard);
    }

    public async Task<List<SchemaMigrationValidationIssueModel>> SchemaMigrationValidateAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationValidateAsync(
            new SchemaMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.ValidationIssues.Select(MapSchemaValidationIssue).ToList();
    }

    public async Task<SchemaMigrationDashboardModel> SchemaMigrationDashboardAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationDashboardAsync(
            new SchemaMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return MapSchemaDashboard(reply.Dashboard);
    }

    public async Task<List<SchemaMigrationObjectComparisonModel>> SchemaMigrationObjectsAsync(
        Guid runGuid,
        string objectType = "",
        string differenceType = "",
        string searchText = "",
        string targetServerName = "",
        string targetDatabaseName = "",
        bool includeDefinitions = false,
        Guid? comparisonGuid = null,
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationObjectsAsync(
            new SchemaMigrationObjectsRequest
            {
                RunGuid = runGuid.ToString(),
                ObjectType = objectType ?? string.Empty,
                DifferenceType = differenceType ?? string.Empty,
                SearchText = searchText ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                IncludeDefinitions = includeDefinitions,
                ComparisonGuid = comparisonGuid?.ToString() ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return reply.Rows.Select(MapSchemaObjectComparison).ToList();
    }

    public async Task<SchemaMigrationObjectComparisonModel?> SchemaMigrationObjectDetailAsync(
        Guid runGuid,
        Guid comparisonGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        if (comparisonGuid == Guid.Empty)
        {
            return null;
        }

        var rows = await SchemaMigrationObjectsAsync(
            runGuid,
            objectType: string.Empty,
            differenceType: string.Empty,
            searchText: string.Empty,
            targetServerName: targetServerName,
            targetDatabaseName: targetDatabaseName,
            includeDefinitions: true,
            comparisonGuid: comparisonGuid,
            cancellationToken: cancellationToken);

        return rows.FirstOrDefault();
    }

    public async Task<SchemaMigrationSelectionResultModel> SchemaMigrationSelectionSaveAsync(
        Guid runGuid,
        IEnumerable<SchemaMigrationSelectionItemModel> selections,
        string notes = "",
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var request = new SchemaMigrationSelectionSaveRequest
        {
            RunGuid = runGuid.ToString(),
            TargetServerName = targetServerName ?? string.Empty,
            TargetDatabaseName = targetDatabaseName ?? string.Empty,
            Notes = notes ?? string.Empty
        };

        foreach (var selection in selections ?? Enumerable.Empty<SchemaMigrationSelectionItemModel>())
        {
            request.Selections.Add(new SchemaMigrationSelectionItem
            {
                ComparisonGuid = selection.ComparisonGuid.ToString(),
                ObjectType = selection.ObjectType ?? string.Empty,
                SchemaName = selection.SchemaName ?? string.Empty,
                ObjectName = selection.ObjectName ?? string.Empty,
                ParentObjectName = selection.ParentObjectName ?? string.Empty,
                IsSelected = selection.IsSelected
            });
        }

        var reply = await _coreClient.SchemaMigrationSelectionSaveAsync(request, cancellationToken: cancellationToken);
        return MapSchemaSelectionResult(reply);
    }

    public async Task<SchemaMigrationSelectionResultModel> SchemaMigrationSelectionClearAsync(
        Guid runGuid,
        string notes = "",
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationSelectionClearAsync(
            new SchemaMigrationSelectionClearRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                Notes = notes ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return MapSchemaSelectionResult(reply);
    }

    public async Task<SchemaMigrationDeploymentPlanModel> SchemaMigrationDeploymentPlanAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationDeploymentPlanAsync(
            new SchemaMigrationRunRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return new SchemaMigrationDeploymentPlanModel
        {
            Rows = reply.Rows.Select(MapSchemaObjectComparison).ToList(),
            SelectedCount = reply.SelectedCount,
            DeployableCount = reply.DeployableCount,
            HasExplicitSelection = reply.HasExplicitSelection
        };
    }

    public async Task<SchemaMigrationOperationResultModel> SchemaMigrationReviewSetAsync(
        Guid runGuid,
        string reviewedByNote,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationReviewSetAsync(
            new SchemaMigrationReviewRequest
            {
                RunGuid = runGuid.ToString(),
                ReviewedByNote = reviewedByNote ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return new SchemaMigrationOperationResultModel
        {
            Success = reply.Success,
            Message = reply.Message ?? string.Empty
        };
    }

    public async Task<List<SchemaMigrationExcludedObjectModel>> SchemaMigrationExcludedObjectsAsync(
        Guid runGuid,
        string targetServerName = "",
        string targetDatabaseName = "",
        bool includeInactive = false,
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationExcludedObjectsAsync(
            new SchemaMigrationExcludedObjectsRequest
            {
                RunGuid = runGuid.ToString(),
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty,
                IncludeInactive = includeInactive
            },
            cancellationToken: cancellationToken);

        return reply.Records.Select(MapSchemaExcludedObject).ToList();
    }

    public async Task<SchemaMigrationExclusionResultModel> SchemaMigrationExclusionUpsertAsync(
        Guid runGuid,
        Guid comparisonGuid,
        string objectType,
        string schemaName,
        string objectName,
        string parentObjectName,
        bool isExcluded,
        string reason,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationExclusionUpsertAsync(
            new SchemaMigrationExclusionUpsertRequest
            {
                RunGuid = runGuid.ToString(),
                ComparisonGuid = comparisonGuid == Guid.Empty ? string.Empty : comparisonGuid.ToString(),
                ObjectType = objectType ?? string.Empty,
                SchemaName = schemaName ?? string.Empty,
                ObjectName = objectName ?? string.Empty,
                ParentObjectName = parentObjectName ?? string.Empty,
                IsExcluded = isExcluded,
                Reason = reason ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return new SchemaMigrationExclusionResultModel
        {
            ExcludedCount = reply.ExcludedCount,
            Message = reply.Message ?? string.Empty
        };
    }

    public async Task<SchemaMigrationOperationResultModel> SchemaMigrationDeploymentOutcomeAsync(
        Guid runGuid,
        string deploymentOutcome,
        string deploymentReference,
        string notes,
        string targetServerName = "",
        string targetDatabaseName = "",
        CancellationToken cancellationToken = default)
    {
        var reply = await _coreClient.SchemaMigrationDeploymentOutcomeAsync(
            new SchemaMigrationDeploymentOutcomeRequest
            {
                RunGuid = runGuid.ToString(),
                DeploymentOutcome = deploymentOutcome ?? string.Empty,
                DeploymentReference = deploymentReference ?? string.Empty,
                Notes = notes ?? string.Empty,
                TargetServerName = targetServerName ?? string.Empty,
                TargetDatabaseName = targetDatabaseName ?? string.Empty
            },
            cancellationToken: cancellationToken);

        return new SchemaMigrationOperationResultModel
        {
            Success = reply.Success,
            Message = reply.Message ?? string.Empty
        };
    }

    private static SchemaMigrationDashboardModel MapSchemaDashboard(SchemaMigrationDashboardMessage? message)
    {
        if (message is null)
        {
            return new SchemaMigrationDashboardModel();
        }

        return new SchemaMigrationDashboardModel
        {
            Run = MapSchemaRun(message.Run),
            EqualCount = message.EqualCount,
            MissingInTargetCount = message.MissingInTargetCount,
            MissingInSourceCount = message.MissingInSourceCount,
            DifferentCount = message.DifferentCount,
            FailCount = message.FailCount,
            WarnCount = message.WarnCount,
            InfoCount = message.InfoCount,
            ExcludedCount = message.ExcludedCount,
            ObjectTypeCounts = message.ObjectTypeCounts.Select(MapSchemaObjectTypeCount).ToList(),
            ValidationIssues = message.ValidationIssues.Select(MapSchemaValidationIssue).ToList(),
            ExecutionLog = message.ExecutionLog.Select(MapSchemaExecutionLog).ToList()
        };
    }

    private static SchemaMigrationRunModel MapSchemaRun(SchemaMigrationRunSummary? message)
    {
        if (message is null)
        {
            return new SchemaMigrationRunModel();
        }

        return new SchemaMigrationRunModel
        {
            RunGuid = Guid.TryParse(message.RunGuid, out var runGuid) ? runGuid : Guid.Empty,
            SourceEnvironment = message.SourceEnvironment ?? string.Empty,
            TargetEnvironment = message.TargetEnvironment ?? string.Empty,
            SourceServerName = message.SourceServerName ?? string.Empty,
            SourceDatabaseName = message.SourceDatabaseName ?? string.Empty,
            TargetServerName = message.TargetServerName ?? string.Empty,
            TargetDatabaseName = message.TargetDatabaseName ?? string.Empty,
            JiraReference = message.JiraReference ?? string.Empty,
            ReleaseReference = message.ReleaseReference ?? string.Empty,
            RunStatus = message.RunStatus ?? string.Empty,
            IsReviewed = message.IsReviewed,
            CreatedOnUtc = message.CreatedOnUtc ?? string.Empty,
            ComparedOnUtc = message.ComparedOnUtc ?? string.Empty,
            ValidatedOnUtc = message.ValidatedOnUtc ?? string.Empty,
            ReviewedOnUtc = message.ReviewedOnUtc ?? string.Empty,
            AppliedOnUtc = message.AppliedOnUtc ?? string.Empty,
            Notes = message.Notes ?? string.Empty,
            SummaryJson = message.SummaryJson ?? string.Empty
        };
    }

    private static SchemaMigrationObjectComparisonModel MapSchemaObjectComparison(SchemaMigrationObjectComparisonRow message)
    {
        return new SchemaMigrationObjectComparisonModel
        {
            ComparisonGuid = Guid.TryParse(message.ComparisonGuid, out var comparisonGuid) ? comparisonGuid : Guid.Empty,
            ObjectType = message.ObjectType ?? string.Empty,
            SchemaName = message.SchemaName ?? string.Empty,
            ObjectName = message.ObjectName ?? string.Empty,
            ParentObjectName = message.ParentObjectName ?? string.Empty,
            DifferenceType = message.DifferenceType ?? string.Empty,
            IsDeployable = message.IsDeployable,
            IsDestructiveRisk = message.IsDestructiveRisk,
            SourceHash = message.SourceHash ?? string.Empty,
            TargetHash = message.TargetHash ?? string.Empty,
            SourceDefinition = message.SourceDefinition ?? string.Empty,
            TargetDefinition = message.TargetDefinition ?? string.Empty,
            Notes = message.Notes ?? string.Empty,
            IsSelected = message.IsSelected,
            HasExplicitSelection = message.HasExplicitSelection
        };
    }

    private static SchemaMigrationExcludedObjectModel MapSchemaExcludedObject(SchemaMigrationExcludedObject message)
    {
        return new SchemaMigrationExcludedObjectModel
        {
            Guid = Guid.TryParse(message.Guid, out var guid) ? guid : Guid.Empty,
            ObjectType = message.ObjectType ?? string.Empty,
            SchemaName = message.SchemaName ?? string.Empty,
            ObjectName = message.ObjectName ?? string.Empty,
            ParentObjectName = message.ParentObjectName ?? string.Empty,
            StableObjectKey = message.StableObjectKey ?? string.Empty,
            Reason = message.Reason ?? string.Empty,
            ExclusionScope = message.ExclusionScope ?? string.Empty,
            OriginServerName = message.OriginServerName ?? string.Empty,
            OriginDatabaseName = message.OriginDatabaseName ?? string.Empty,
            ExcludedByUserId = message.ExcludedByUserId,
            ExcludedOnUtcText = message.ExcludedOnUtc ?? string.Empty,
            UnexcludedOnUtcText = message.UnexcludedOnUtc ?? string.Empty,
            LastSeenRunGuid = Guid.TryParse(message.LastSeenRunGuid, out var lastSeenRunGuid) ? lastSeenRunGuid : Guid.Empty,
            LastSeenOnUtcText = message.LastSeenOnUtc ?? string.Empty,
            RowStatus = message.RowStatus,
            IsSynchronizedToTarget = message.IsSynchronizedToTarget
        };
    }

    private static SchemaMigrationSelectionResultModel MapSchemaSelectionResult(SchemaMigrationSelectionResponse message)
    {
        return new SchemaMigrationSelectionResultModel
        {
            Success = message.Success,
            Message = message.Message ?? string.Empty,
            SelectedCount = message.SelectedCount,
            DeployableCount = message.DeployableCount,
            ExplicitSelectionCount = message.ExplicitSelectionCount
        };
    }

    private static SchemaMigrationObjectTypeCountModel MapSchemaObjectTypeCount(SchemaMigrationObjectTypeCount message)
    {
        return new SchemaMigrationObjectTypeCountModel
        {
            ObjectType = message.ObjectType ?? string.Empty,
            DifferenceType = message.DifferenceType ?? string.Empty,
            Count = message.Count
        };
    }

    private static SchemaMigrationValidationIssueModel MapSchemaValidationIssue(SchemaMigrationValidationIssue message)
    {
        return new SchemaMigrationValidationIssueModel
        {
            IssueGuid = Guid.TryParse(message.IssueGuid, out var issueGuid) ? issueGuid : Guid.Empty,
            ComparisonGuid = Guid.TryParse(message.ComparisonGuid, out var comparisonGuid) ? comparisonGuid : Guid.Empty,
            Severity = message.Severity ?? string.Empty,
            IssueCode = message.IssueCode ?? string.Empty,
            IssueMessage = message.IssueMessage ?? string.Empty,
            ObjectType = message.ObjectType ?? string.Empty,
            SchemaName = message.SchemaName ?? string.Empty,
            ObjectName = message.ObjectName ?? string.Empty,
            DetailsJson = message.DetailsJson ?? string.Empty
        };
    }

    private static SchemaMigrationExecutionLogItemModel MapSchemaExecutionLog(SchemaMigrationExecutionLogItem message)
    {
        return new SchemaMigrationExecutionLogItemModel
        {
            StepName = message.StepName ?? string.Empty,
            StepStatus = message.StepStatus ?? string.Empty,
            Message = message.Message ?? string.Empty,
            DetailsJson = message.DetailsJson ?? string.Empty,
            CreatedOnUtc = message.CreatedOnUtc ?? string.Empty
        };
    }
}
