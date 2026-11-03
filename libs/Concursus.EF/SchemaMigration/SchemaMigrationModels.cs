namespace Concursus.EF.SchemaMigration;

public sealed record SchemaObjectSnapshot(
    string ObjectType,
    string SchemaName,
    string ObjectName,
    string ParentObjectName,
    string Definition,
    string Hash,
    string OperationalHash,
    bool SupportsOperationalSchemaBindingLifecycle)
{
    public string Key => $"{ObjectType}|{SchemaName}|{ObjectName}|{ParentObjectName}";
}

public sealed class SchemaExcludedObjectRecord
{
    public long ID { get; init; }
    public Guid Guid { get; init; }
    public string ObjectType { get; init; } = string.Empty;
    public string SchemaName { get; init; } = string.Empty;
    public string ObjectName { get; init; } = string.Empty;
    public string ParentObjectName { get; init; } = string.Empty;
    public string StableObjectKey { get; init; } = string.Empty;
    public string Reason { get; init; } = string.Empty;
    public string ExclusionScope { get; init; } = string.Empty;
    public string OriginServerName { get; init; } = string.Empty;
    public string OriginDatabaseName { get; init; } = string.Empty;
    public int ExcludedByUserId { get; init; }
    public string ExcludedOnUtc { get; init; } = string.Empty;
    public string UnexcludedOnUtc { get; init; } = string.Empty;
    public Guid LastSeenRunGuid { get; init; }
    public string LastSeenOnUtc { get; init; } = string.Empty;
    public int RowStatus { get; init; }
    public bool IsActive => RowStatus != 0 && RowStatus != 254;
}

public sealed record SchemaObjectIdentity(
    string ObjectType,
    string SchemaName,
    string ObjectName,
    string ParentObjectName)
{
    public bool IsValid =>
        !string.IsNullOrWhiteSpace(ObjectType)
        && !string.IsNullOrWhiteSpace(SchemaName)
        && !string.IsNullOrWhiteSpace(ObjectName);

    public string DisplayName => string.IsNullOrWhiteSpace(ParentObjectName)
        ? $"{SchemaName}.{ObjectName}"
        : $"{SchemaName}.{ParentObjectName}.{ObjectName}";
}

public sealed record SchemaExclusionSyncResult(
    IReadOnlyList<SchemaExcludedObjectRecord> SourceRecords,
    int SynchronizedCount,
    int RemovedTargetOnlyCount)
{
    public int ActiveCount => SourceRecords.Count(x => x.IsActive);
    public HashSet<string> ActiveStableObjectKeys => SourceRecords
        .Where(x => x.IsActive)
        .Select(x => x.StableObjectKey)
        .ToHashSet(StringComparer.OrdinalIgnoreCase);
}

public sealed class SchemaComparisonDraft
{
    public Guid ComparisonGuid { get; init; }
    public string ObjectType { get; init; } = string.Empty;
    public string SchemaName { get; init; } = string.Empty;
    public string ObjectName { get; init; } = string.Empty;
    public string ParentObjectName { get; init; } = string.Empty;
    public string DifferenceType { get; init; } = string.Empty;
    public string SourceHash { get; init; } = string.Empty;
    public string TargetHash { get; init; } = string.Empty;
    public string SourceDefinition { get; init; } = string.Empty;
    public string TargetDefinition { get; init; } = string.Empty;
    public bool IsDeployable { get; init; }
    public bool IsDestructiveRisk { get; init; }
    public string Notes { get; init; } = string.Empty;
}

public sealed record SchemaSelectionCounts(int DeployableCount, int SelectedCount, int ExplicitSelectionCount);

public sealed class SchemaSelectionDraft
{
    public Guid ComparisonGuid { get; init; }
    public string ObjectType { get; init; } = string.Empty;
    public string SchemaName { get; init; } = string.Empty;
    public string ObjectName { get; init; } = string.Empty;
    public string ParentObjectName { get; init; } = string.Empty;
    public bool IsSelected { get; init; }
    public bool IsDestructiveRisk { get; init; }
    public string SelectionNote { get; init; } = string.Empty;
    public bool IsNewTable { get; init; }
    public bool CopyReferenceData { get; init; }
    public string? NewTableCaptureJson { get; set; }
}

public sealed class SchemaValidationDraft
{
    public Guid ComparisonGuid { get; init; }
    public string Severity { get; init; } = string.Empty;
    public string IssueCode { get; init; } = string.Empty;
    public string IssueMessage { get; init; } = string.Empty;
    public string ObjectType { get; init; } = string.Empty;
    public string SchemaName { get; init; } = string.Empty;
    public string ObjectName { get; init; } = string.Empty;
    public string DetailsJson { get; init; } = "{}";
}
