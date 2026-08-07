using CymBuild.Database.IntegrationTests.Infrastructure;

namespace CymBuild.Database.IntegrationTests.Schema;

public sealed class DatabaseContractTests
{
    [Fact]
    public async Task ConnectionTargetsDedicatedTestDatabase()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();

        Assert.True(string.Equals(database.DatabaseName, connection.Database, StringComparison.OrdinalIgnoreCase));
        Assert.True(
            database.DatabaseName.StartsWith("CymBuild_Test_", StringComparison.OrdinalIgnoreCase)
            || string.Equals(
                database.DatabaseName,
                Environment.GetEnvironmentVariable(SqlTestDatabase.AllowedDatabaseEnvironmentVariable),
                StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task RequiredCoreObjectsExist()
    {
        var database = SqlTestDatabase.FromEnvironment();
        const string sql = """
SELECT COUNT_BIG(1)
FROM (VALUES
    (N'SCore', N'DataObjects', N'U'),
    (N'SCore', N'DataObjectTransition', N'U'),
    (N'SCore', N'IntegrationOutbox', N'U'),
    (N'SCore', N'UpsertDataObject', N'P'),
    (N'SCore', N'DataObjectTransitionUpsert', N'P'),
    (N'SCore', N'NonActivityEventsUpsert', N'P')
) AS required_objects(SchemaName, ObjectName, ObjectType)
WHERE OBJECT_ID(QUOTENAME(SchemaName) + N'.' + QUOTENAME(ObjectName), ObjectType) IS NOT NULL;
""";

        var count = await database.ExecuteScalarAsync<long>(sql);
        Assert.Equal(6L, count);
    }

    [Fact]
    public async Task DataObjectsIdentityColumnsAreMandatoryAndVersioned()
    {
        var database = SqlTestDatabase.FromEnvironment();
        const string sql = """
SELECT COUNT_BIG(1)
FROM sys.columns AS c
JOIN sys.tables AS t ON t.object_id = c.object_id
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
WHERE s.name = N'SCore'
  AND t.name = N'DataObjects'
  AND
  (
      (c.name = N'Guid' AND c.is_nullable = 0 AND ty.name = N'uniqueidentifier')
   OR (c.name = N'EntityTypeId' AND c.is_nullable = 0 AND ty.name = N'int')
   OR (c.name = N'RowStatus' AND c.is_nullable = 0 AND ty.name = N'tinyint')
   OR (c.name = N'RowVersion' AND c.is_nullable = 0 AND ty.name IN (N'timestamp', N'rowversion'))
  );
""";

        var count = await database.ExecuteScalarAsync<long>(sql);
        Assert.Equal(4L, count);
    }

    [Theory]
    [InlineData("SCore", "DataObjectTransition", "IX_DataObjectTransition_Active_DataObjectGuid_ID")]
    [InlineData("SCore", "IntegrationOutbox", "IX_IntegrationOutbox_PublishClaim")]
    public async Task ActiveFilteredIndexesExcludeRetiredStatuses(string schemaName, string tableName, string indexName)
    {
        var database = SqlTestDatabase.FromEnvironment();
        const string sql = """
SELECT i.filter_definition
FROM sys.indexes AS i
JOIN sys.tables AS t ON t.object_id = i.object_id
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = @SchemaName
  AND t.name = @TableName
  AND i.name = @IndexName;
""";

        await using var connection = await database.OpenConnectionAsync();
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction: null,
            sql,
            new[]
            {
                new SqlParameter("@SchemaName", System.Data.SqlDbType.NVarChar, 128) { Value = schemaName },
                new SqlParameter("@TableName", System.Data.SqlDbType.NVarChar, 128) { Value = tableName },
                new SqlParameter("@IndexName", System.Data.SqlDbType.NVarChar, 128) { Value = indexName }
            });

        var filterDefinition = Convert.ToString(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
        Assert.False(string.IsNullOrWhiteSpace(filterDefinition));

        var normalized = filterDefinition!.Replace(" ", string.Empty, StringComparison.Ordinal)
            .Replace("[", string.Empty, StringComparison.Ordinal)
            .Replace("]", string.Empty, StringComparison.Ordinal)
            .ToUpperInvariant();

        Assert.Contains("ROWSTATUS", normalized, StringComparison.Ordinal);
        Assert.Contains("<>(0)", normalized, StringComparison.Ordinal);
        Assert.Contains("<>(254)", normalized, StringComparison.Ordinal);
    }

    [Fact]
    public async Task WorkflowTransitionGuidIsUnique()
    {
        var database = SqlTestDatabase.FromEnvironment();
        const string sql = """
SELECT COUNT_BIG(1)
FROM sys.indexes AS i
JOIN sys.index_columns AS ic
  ON ic.object_id = i.object_id
 AND ic.index_id = i.index_id
JOIN sys.columns AS c
  ON c.object_id = ic.object_id
 AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID(N'SCore.DataObjectTransition')
  AND i.is_unique = 1
  AND c.name = N'Guid';
""";

        var count = await database.ExecuteScalarAsync<long>(sql);
        Assert.True(count >= 1);
    }
}
