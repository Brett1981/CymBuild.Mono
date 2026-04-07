namespace Concursus.API.Client.Models.Monitoring;

public sealed class CymBuildSchemaDashboardResponseModel
{
    public CymBuildSchemaSummaryModel Summary { get; set; } = new();
    public List<CymBuildSchemaObjectCountModel> ObjectCounts { get; set; } = new();
    public List<CymBuildSchemaIntegrityCheckModel> IntegrityChecks { get; set; } = new();
    public List<CymBuildSchemaLargestTableModel> LargestTables { get; set; } = new();
    public List<CymBuildSchemaBoundObjectModel> SchemaBoundObjects { get; set; } = new();
}

public sealed class CymBuildSchemaSummaryModel
{
    public DateTime SnapshotUtc { get; set; }
    public int SchemasMonitored { get; set; }
    public int TotalObjectsMonitored { get; set; }
    public int TableCount { get; set; }
    public int ViewCount { get; set; }
    public int ProcedureCount { get; set; }
    public int FunctionCount { get; set; }
    public int NonSchemaBoundObjectCount { get; set; }
    public string LargestTableName { get; set; } = string.Empty;
    public long LargestTableRowCount { get; set; }
    public decimal LargestTableReservedMB { get; set; }
}

public sealed class CymBuildSchemaObjectCountModel
{
    public string SchemaName { get; set; } = string.Empty;
    public int TableCount { get; set; }
    public int ViewCount { get; set; }
    public int ProcedureCount { get; set; }
    public int FunctionCount { get; set; }
    public int TotalObjectCount { get; set; }
}

public sealed class CymBuildSchemaIntegrityCheckModel
{
    public string CheckName { get; set; } = string.Empty;
    public bool IsOk { get; set; }
    public string StatusText { get; set; } = string.Empty;
    public string Detail { get; set; } = string.Empty;
}

public sealed class CymBuildSchemaLargestTableModel
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public long RowCount { get; set; }
    public decimal ReservedMB { get; set; }
    public decimal UsedMB { get; set; }
    public decimal DataMB { get; set; }
    public decimal IndexMB { get; set; }
}

public sealed class CymBuildSchemaBoundObjectModel
{
    public string SchemaName { get; set; } = string.Empty;
    public string ObjectName { get; set; } = string.Empty;
    public string ObjectType { get; set; } = string.Empty;
    public string ObjectTypeDesc { get; set; } = string.Empty;
    public bool IsSchemaBound { get; set; }
    public string StatusText { get; set; } = string.Empty;
}