namespace Concursus.EF.SchemaMigration;

/// <summary>Persisted SMigration.Schema_Run row, formatted exactly as the workbench API returns it.</summary>
public sealed class SchemaRunRecord
{
    public string RunGuid { get; init; } = string.Empty;
    public string SourceEnvironment { get; init; } = string.Empty;
    public string TargetEnvironment { get; init; } = string.Empty;
    public string SourceServerName { get; init; } = string.Empty;
    public string SourceDatabaseName { get; init; } = string.Empty;
    public string TargetServerName { get; init; } = string.Empty;
    public string TargetDatabaseName { get; init; } = string.Empty;
    public string JiraReference { get; init; } = string.Empty;
    public string ReleaseReference { get; init; } = string.Empty;
    public string RunStatus { get; init; } = string.Empty;
    public bool IsReviewed { get; init; }
    public string CreatedOnUtc { get; init; } = string.Empty;
    public string ComparedOnUtc { get; init; } = string.Empty;
    public string ValidatedOnUtc { get; init; } = string.Empty;
    public string ReviewedOnUtc { get; init; } = string.Empty;
    public string AppliedOnUtc { get; init; } = string.Empty;
    public string Notes { get; init; } = string.Empty;
    public string SummaryJson { get; init; } = string.Empty;
    public string SourceSyncedOnUtc { get; init; } = string.Empty;
    public string SourceSyncCommit { get; init; } = string.Empty;
}

/// <summary>Persisted SMigration.Schema_ObjectComparisons row with its effective selection state.</summary>
public sealed class SchemaComparisonRowRecord
{
    public string ComparisonGuid { get; init; } = string.Empty;
    public string ObjectType { get; init; } = string.Empty;
    public string SchemaName { get; init; } = string.Empty;
    public string ObjectName { get; init; } = string.Empty;
    public string ParentObjectName { get; init; } = string.Empty;
    public string DifferenceType { get; init; } = string.Empty;
    public bool IsDeployable { get; init; }
    public bool IsDestructiveRisk { get; init; }
    public string SourceHash { get; init; } = string.Empty;
    public string TargetHash { get; init; } = string.Empty;
    public string SourceDefinition { get; init; } = string.Empty;
    public string TargetDefinition { get; init; } = string.Empty;
    public string Notes { get; init; } = string.Empty;
    public bool IsSelected { get; init; }
    public bool HasExplicitSelection { get; init; }
    public bool CopyReferenceData { get; init; }
}

public sealed class SchemaValidationIssueRecord
{
    public string IssueGuid { get; init; } = string.Empty;
    public string ComparisonGuid { get; init; } = string.Empty;
    public string Severity { get; init; } = string.Empty;
    public string IssueCode { get; init; } = string.Empty;
    public string IssueMessage { get; init; } = string.Empty;
    public string ObjectType { get; init; } = string.Empty;
    public string SchemaName { get; init; } = string.Empty;
    public string ObjectName { get; init; } = string.Empty;
    public string DetailsJson { get; init; } = string.Empty;
}

/// <summary>Active validation issues for a run, ordered Fail, Warn, Info.</summary>
public sealed class SchemaValidationResult
{
    public List<SchemaValidationIssueRecord> ValidationIssues { get; } = [];
    public int FailCount { get; set; }
    public int WarnCount { get; set; }
    public int InfoCount { get; set; }
}

/// <summary>One saved-selection entry, as supplied by the workbench (Guid-only, or legacy full object key).</summary>
public sealed class SchemaSelectionRequestItem
{
    public string ComparisonGuid { get; init; } = string.Empty;
    public string ObjectType { get; init; } = string.Empty;
    public string SchemaName { get; init; } = string.Empty;
    public string ObjectName { get; init; } = string.Empty;
    public string ParentObjectName { get; init; } = string.Empty;
    public bool IsSelected { get; init; }
    public bool CopyReferenceData { get; init; }
}

public sealed record SchemaRunCreateOptions(
    string SourceEnvironment,
    string SourceServerName,
    string SourceDatabaseName,
    string TargetEnvironment,
    string TargetServerName,
    string TargetDatabaseName,
    string JiraReference,
    string ReleaseReference,
    string Notes);

public sealed record SchemaOperationResult(bool Success, string Message);

/// <summary>Newest accepted (Reviewed) run that the controlled runner has not applied yet.</summary>
public sealed record SchemaAcceptedRunInfo(Guid RunGuid, DateTime? ComparedOnUtc);

public sealed record SchemaHeadlessSkippedRow(SchemaComparisonRowRecord Row, string ReasonCode, string Reason);

public sealed record SchemaHeadlessSelectionPlan(
    IReadOnlyList<SchemaComparisonRowRecord> Selected,
    IReadOnlyList<SchemaHeadlessSkippedRow> Skipped);

/// <summary>Comparison rows read through the capped (TOP 5000) workbench query.</summary>
public sealed record SchemaComparisonRowsPage(IReadOnlyList<SchemaComparisonRowRecord> Rows, bool MayBeTruncated);

public enum SchemaMigrationErrorKind
{
    NotFound,
    FailedPrecondition,
    InvalidArgument
}

/// <summary>
/// A handled Schema Migration refusal. The gRPC service maps <see cref="Kind"/> to the matching
/// status code with the unchanged message; the CLI reports the message.
/// </summary>
public sealed class SchemaMigrationException : Exception
{
    public SchemaMigrationException(SchemaMigrationErrorKind kind, string message)
        : base(message)
    {
        Kind = kind;
    }

    public SchemaMigrationErrorKind Kind { get; }
}
