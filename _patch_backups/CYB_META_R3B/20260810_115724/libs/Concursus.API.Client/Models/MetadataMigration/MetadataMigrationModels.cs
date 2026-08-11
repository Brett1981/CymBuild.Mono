namespace Concursus.API.Client.Models.MetadataMigration;

public sealed class MetadataMigrationRunModel
{
    public Guid RunGuid { get; set; }
    public string SourceEnvironment { get; set; } = string.Empty;
    public string TargetEnvironment { get; set; } = string.Empty;
    public string SourceServerName { get; set; } = string.Empty;
    public string SourceDatabaseName { get; set; } = string.Empty;
    public string TargetServerName { get; set; } = string.Empty;
    public string TargetDatabaseName { get; set; } = string.Empty;
    public string RunStatus { get; set; } = string.Empty;
    public bool IsValidateOnly { get; set; }
    public string CreatedOnUtcText { get; set; } = string.Empty;
    public string ValidatedOnUtcText { get; set; } = string.Empty;
    public string AppliedOnUtcText { get; set; } = string.Empty;
    public string SummaryJson { get; set; } = string.Empty;
}

public sealed class MetadataMigrationLookupItemModel
{
    public Guid Guid { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
}

public sealed class MetadataMigrationTableCountModel
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public string DifferenceType { get; set; } = string.Empty;
    public int Count { get; set; }

    public string EntityName => string.IsNullOrWhiteSpace(TableName) ? SchemaName : $"{SchemaName}.{TableName}";
}

public sealed class MetadataMigrationValidationIssueModel
{
    public Guid Guid { get; set; }
    public Guid RegistryGuid { get; set; }
    public Guid SourceRowGuid { get; set; }
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public string Severity { get; set; } = string.Empty;
    public string IssueCode { get; set; } = string.Empty;
    public string IssueMessage { get; set; } = string.Empty;
    public string DetailsJson { get; set; } = string.Empty;
    public string EntityName => string.IsNullOrWhiteSpace(TableName) ? SchemaName : $"{SchemaName}.{TableName}";
}

public sealed class MetadataMigrationIdentityMapModel
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public int MapRows { get; set; }
    public int MissingTargetRows { get; set; }
    public string EntityName => string.IsNullOrWhiteSpace(TableName) ? SchemaName : $"{SchemaName}.{TableName}";
}

public sealed class MetadataMigrationIdentityMapDetailModel
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public Guid SourceRowGuid { get; set; }
    public long SourceRowId { get; set; }
    public long TargetRowId { get; set; }
    public string DifferenceType { get; set; } = string.Empty;
    public string SourceDisplayName { get; set; } = string.Empty;
    public string IssueCode { get; set; } = string.Empty;
    public string IssueStatus { get; set; } = string.Empty;
    public string Reason { get; set; } = string.Empty;
    public string SuggestedAction { get; set; } = string.Empty;
    public bool IsResolved { get; set; }
    public bool IsIgnoredIssue { get; set; }
    public string IgnoreReason { get; set; } = string.Empty;
    public string IgnoredOnUtcText { get; set; } = string.Empty;
    public string SourcePayloadJson { get; set; } = string.Empty;
    public bool HasOverride { get; set; }
    public Guid OverrideTargetRowGuid { get; set; }
    public string OverrideTargetDisplayName { get; set; } = string.Empty;
    public string OverrideReason { get; set; } = string.Empty;
    public string EntityName => string.IsNullOrWhiteSpace(TableName) ? SchemaName : $"{SchemaName}.{TableName}";
    public bool NeedsReview => !IsResolved && !IsIgnoredIssue && !HasOverride;
}

public sealed class MetadataMigrationIdentityMapCandidateModel
{
    public Guid TargetRowGuid { get; set; }
    public long TargetRowId { get; set; }
    public string TargetDisplayName { get; set; } = string.Empty;
    public string MatchReason { get; set; } = string.Empty;
    public int MatchScore { get; set; }
    public string TargetPayloadJson { get; set; } = string.Empty;
}

public sealed class MetadataMigrationIdentityMapCandidatesResultModel
{
    public string SourceDisplayName { get; set; } = string.Empty;
    public string SourcePayloadJson { get; set; } = string.Empty;
    public List<MetadataMigrationIdentityMapCandidateModel> Rows { get; set; } = new();
}

public sealed class MetadataMigrationIdentityMapDetailsResultModel
{
    public List<MetadataMigrationIdentityMapDetailModel> Rows { get; set; } = new();
    public int UnresolvedCount { get; set; }
    public int IgnoredCount { get; set; }
    public int ResolvedCount { get; set; }
}

public sealed class MetadataMigrationIdentityMapIssueResultModel
{
    public int UnresolvedCount { get; set; }
    public int IgnoredCount { get; set; }
    public string Message { get; set; } = string.Empty;
}

public sealed class MetadataMigrationExecutionLogItemModel
{
    public string StepName { get; set; } = string.Empty;
    public string StepStatus { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string DetailsJson { get; set; } = string.Empty;
    public string CreatedOnUtcText { get; set; } = string.Empty;
}

public sealed class MetadataMigrationStagedRowModel
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public Guid SourceRowGuid { get; set; }
    public long SourceRowId { get; set; }
    public string DifferenceType { get; set; } = string.Empty;
    public string SourcePayloadJson { get; set; } = string.Empty;
    public string TargetPayloadJson { get; set; } = string.Empty;
    public Dictionary<string, string> SourceValues { get; set; } = new();
    public Dictionary<string, string> TargetValues { get; set; } = new();
    public bool IsSelected { get; set; }
    public bool IsIgnored { get; set; }
    public string IgnoreReason { get; set; } = string.Empty;
    public string IgnoredOnUtcText { get; set; } = string.Empty;
    public string EntityName => string.IsNullOrWhiteSpace(TableName) ? SchemaName : $"{SchemaName}.{TableName}";
}

public sealed class MetadataMigrationDiffRowModel
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public Guid SourceRowGuid { get; set; }
    public string DifferenceType { get; set; } = string.Empty;
    public Dictionary<string, string> SourceValues { get; set; } = new();
    public Dictionary<string, string> TargetValues { get; set; } = new();
    public List<string> DifferingColumns { get; set; } = new();
    public bool IsSelected { get; set; }
    public bool IsIgnored { get; set; }
    public string IgnoreReason { get; set; } = string.Empty;
    public string IgnoredOnUtcText { get; set; } = string.Empty;
    public string EntityName => string.IsNullOrWhiteSpace(TableName) ? SchemaName : $"{SchemaName}.{TableName}";
}

public sealed class MetadataMigrationSelectionItemModel
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public Guid SourceRowGuid { get; set; }
    public string DifferenceType { get; set; } = string.Empty;
    public bool IsSelected { get; set; }
}

public sealed class MetadataMigrationSelectionResultModel
{
    public int SelectedCount { get; set; }
    public string Message { get; set; } = string.Empty;
}

public sealed class MetadataMigrationIgnoreResultModel
{
    public int IgnoredCount { get; set; }
    public string Message { get; set; } = string.Empty;
}

public sealed class MetadataMigrationIgnoredRecordModel
{
    public Guid Guid { get; set; }
    public string DatabaseName { get; set; } = string.Empty;
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public Guid SourceRowGuid { get; set; }
    public string StableRecordKey { get; set; } = string.Empty;
    public string Reason { get; set; } = string.Empty;
    public int IgnoredByUserId { get; set; }
    public string IgnoredOnUtcText { get; set; } = string.Empty;
    public string UnignoredOnUtcText { get; set; } = string.Empty;
    public int RowStatus { get; set; }
    public string EntityName => string.IsNullOrWhiteSpace(TableName) ? SchemaName : $"{SchemaName}.{TableName}";
    public bool IsActive => RowStatus != 0 && RowStatus != 254;
}


public sealed class MetadataMigrationEntityTypeScopeRowModel
{
    public Guid EntityTypeGuid { get; set; }
    public string Name { get; set; } = string.Empty;
    public int RowStatus { get; set; }
    public bool IsMetaData { get; set; }
    public bool HasDocuments { get; set; }
    public bool IsRootEntity { get; set; }
    public bool IsDeletable { get; set; }
    public bool HasMainHoBT { get; set; }
    public string MainHoBTSchemaName { get; set; } = string.Empty;
    public string MainHoBTObjectName { get; set; } = string.Empty;

    public string MainHoBTDisplayName => HasMainHoBT
        ? $"{MainHoBTSchemaName}.{MainHoBTObjectName}"
        : "-";
}

public sealed class MetadataMigrationEntityTypeScopeUpdateItemModel
{
    public Guid EntityTypeGuid { get; set; }
    public bool IsMetaData { get; set; }
}

public sealed class MetadataMigrationEntityTypeScopeSaveResultModel
{
    public int UpdatedCount { get; set; }
    public string Message { get; set; } = string.Empty;
}


public sealed class MetadataMigrationApplyPreviewRowModel
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public Guid SourceRowGuid { get; set; }
    public long SourceRowId { get; set; }
    public string DifferenceType { get; set; } = string.Empty;
    public bool IsSelected { get; set; }
    public bool IsIgnored { get; set; }
    public bool HasValidationFailure { get; set; }
    public string ApplyAction { get; set; } = string.Empty;
    public string SkipReason { get; set; } = string.Empty;
    public string ChangedColumns { get; set; } = string.Empty;
    public int RunValidationFailureCount { get; set; }

    public string EntityName => string.IsNullOrWhiteSpace(TableName) ? SchemaName : $"{SchemaName}.{TableName}";
    public bool WillApply => ApplyAction.Equals("Apply", StringComparison.OrdinalIgnoreCase);
    public bool IsBlocked => ApplyAction.Equals("Blocked", StringComparison.OrdinalIgnoreCase);
}

public sealed class MetadataMigrationApplyPreviewModel
{
    public bool ApplySelectedOnly { get; set; }
    public int ApplyCount { get; set; }
    public int SkipCount { get; set; }
    public int BlockedCount { get; set; }
    public int IgnoredSkipCount { get; set; }
    public int RunValidationFailureCount { get; set; }
    public List<MetadataMigrationApplyPreviewRowModel> Rows { get; set; } = new();
}

public sealed class MetadataMigrationDashboardModel
{
    public MetadataMigrationRunModel? Run { get; set; }
    public int FailCount { get; set; }
    public int WarnCount { get; set; }
    public int InfoCount { get; set; }
    public int InsertCount { get; set; }
    public int UpdateCount { get; set; }
    public int NoChangeCount { get; set; }
    public int MapRows { get; set; }
    public int MissingTargetRows { get; set; }
    public int SelectedCount { get; set; }
    public int IgnoredCount { get; set; }
    public List<MetadataMigrationTableCountModel> StagedCounts { get; set; } = new();
    public List<MetadataMigrationValidationIssueModel> ValidationIssues { get; set; } = new();
    public List<MetadataMigrationIdentityMapModel> IdentityMap { get; set; } = new();
    public List<MetadataMigrationExecutionLogItemModel> ExecutionLog { get; set; } = new();
}
