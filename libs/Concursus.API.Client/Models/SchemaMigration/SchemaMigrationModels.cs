namespace Concursus.API.Client.Models.SchemaMigration;

public sealed class SchemaMigrationRunModel
{
    public Guid RunGuid { get; set; }
    public string SourceEnvironment { get; set; } = string.Empty;
    public string TargetEnvironment { get; set; } = string.Empty;
    public string SourceServerName { get; set; } = string.Empty;
    public string SourceDatabaseName { get; set; } = string.Empty;
    public string TargetServerName { get; set; } = string.Empty;
    public string TargetDatabaseName { get; set; } = string.Empty;
    public string JiraReference { get; set; } = string.Empty;
    public string ReleaseReference { get; set; } = string.Empty;
    public string RunStatus { get; set; } = string.Empty;
    public bool IsReviewed { get; set; }
    public string CreatedOnUtc { get; set; } = string.Empty;
    public string ComparedOnUtc { get; set; } = string.Empty;
    public string ValidatedOnUtc { get; set; } = string.Empty;
    public string ReviewedOnUtc { get; set; } = string.Empty;
    public string AppliedOnUtc { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
    public string SummaryJson { get; set; } = string.Empty;
}

public sealed class SchemaMigrationObjectComparisonModel
{
    public Guid ComparisonGuid { get; set; }
    public string ObjectType { get; set; } = string.Empty;
    public string SchemaName { get; set; } = string.Empty;
    public string ObjectName { get; set; } = string.Empty;
    public string ParentObjectName { get; set; } = string.Empty;
    public string DifferenceType { get; set; } = string.Empty;
    public bool IsDeployable { get; set; }
    public bool IsDestructiveRisk { get; set; }
    public string SourceHash { get; set; } = string.Empty;
    public string TargetHash { get; set; } = string.Empty;
    public string SourceDefinition { get; set; } = string.Empty;
    public string TargetDefinition { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
    public bool IsSelected { get; set; }
    public bool HasExplicitSelection { get; set; }
}

public sealed class SchemaMigrationExcludedObjectModel
{
    public Guid Guid { get; set; }
    public string ObjectType { get; set; } = string.Empty;
    public string SchemaName { get; set; } = string.Empty;
    public string ObjectName { get; set; } = string.Empty;
    public string ParentObjectName { get; set; } = string.Empty;
    public string StableObjectKey { get; set; } = string.Empty;
    public string Reason { get; set; } = string.Empty;
    public string ExclusionScope { get; set; } = string.Empty;
    public string OriginServerName { get; set; } = string.Empty;
    public string OriginDatabaseName { get; set; } = string.Empty;
    public int ExcludedByUserId { get; set; }
    public string ExcludedOnUtcText { get; set; } = string.Empty;
    public string UnexcludedOnUtcText { get; set; } = string.Empty;
    public Guid LastSeenRunGuid { get; set; }
    public string LastSeenOnUtcText { get; set; } = string.Empty;
    public int RowStatus { get; set; }
    public bool IsSynchronizedToTarget { get; set; }
    public bool IsActive => RowStatus != 0 && RowStatus != 254;
    public string DisplayName => string.IsNullOrWhiteSpace(ParentObjectName)
        ? $"{SchemaName}.{ObjectName}"
        : $"{SchemaName}.{ParentObjectName}.{ObjectName}";
}

public sealed class SchemaMigrationExclusionResultModel
{
    public int ExcludedCount { get; set; }
    public string Message { get; set; } = string.Empty;
}

public sealed class SchemaMigrationSelectionItemModel
{
    public Guid ComparisonGuid { get; set; }
    public string ObjectType { get; set; } = string.Empty;
    public string SchemaName { get; set; } = string.Empty;
    public string ObjectName { get; set; } = string.Empty;
    public string ParentObjectName { get; set; } = string.Empty;
    public bool IsSelected { get; set; }
}

public sealed class SchemaMigrationSelectionResultModel
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public int SelectedCount { get; set; }
    public int DeployableCount { get; set; }
    public int ExplicitSelectionCount { get; set; }
}

public sealed class SchemaMigrationDeploymentPlanModel
{
    public List<SchemaMigrationObjectComparisonModel> Rows { get; set; } = new();
    public int SelectedCount { get; set; }
    public int DeployableCount { get; set; }
    public bool HasExplicitSelection { get; set; }
}

public sealed class SchemaMigrationValidationIssueModel
{
    public Guid IssueGuid { get; set; }
    public Guid ComparisonGuid { get; set; }
    public string Severity { get; set; } = string.Empty;
    public string IssueCode { get; set; } = string.Empty;
    public string IssueMessage { get; set; } = string.Empty;
    public string ObjectType { get; set; } = string.Empty;
    public string SchemaName { get; set; } = string.Empty;
    public string ObjectName { get; set; } = string.Empty;
    public string DetailsJson { get; set; } = string.Empty;
}

public sealed class SchemaMigrationExecutionLogItemModel
{
    public string StepName { get; set; } = string.Empty;
    public string StepStatus { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string DetailsJson { get; set; } = string.Empty;
    public string CreatedOnUtc { get; set; } = string.Empty;
}

public sealed class SchemaMigrationDashboardModel
{
    public SchemaMigrationRunModel Run { get; set; } = new();
    public int EqualCount { get; set; }
    public int MissingInTargetCount { get; set; }
    public int MissingInSourceCount { get; set; }
    public int DifferentCount { get; set; }
    public int FailCount { get; set; }
    public int WarnCount { get; set; }
    public int InfoCount { get; set; }
    public int ExcludedCount { get; set; }
    public List<SchemaMigrationObjectTypeCountModel> ObjectTypeCounts { get; set; } = new();
    public List<SchemaMigrationValidationIssueModel> ValidationIssues { get; set; } = new();
    public List<SchemaMigrationExecutionLogItemModel> ExecutionLog { get; set; } = new();
}

public sealed class SchemaMigrationObjectTypeCountModel
{
    public string ObjectType { get; set; } = string.Empty;
    public string DifferenceType { get; set; } = string.Empty;
    public int Count { get; set; }
}

public sealed class SchemaMigrationOperationResultModel
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
}
