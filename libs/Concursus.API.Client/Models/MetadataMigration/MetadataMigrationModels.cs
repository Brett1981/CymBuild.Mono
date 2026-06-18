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
    public string EntityName => string.IsNullOrWhiteSpace(TableName) ? SchemaName : $"{SchemaName}.{TableName}";
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
    public List<MetadataMigrationTableCountModel> StagedCounts { get; set; } = new();
    public List<MetadataMigrationValidationIssueModel> ValidationIssues { get; set; } = new();
    public List<MetadataMigrationIdentityMapModel> IdentityMap { get; set; } = new();
    public List<MetadataMigrationExecutionLogItemModel> ExecutionLog { get; set; } = new();
}
