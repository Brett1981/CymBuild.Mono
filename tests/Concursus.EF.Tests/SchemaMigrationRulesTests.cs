using Concursus.EF.MigrationCli;
using Concursus.EF.SchemaMigration;
using Xunit;

namespace Concursus.EF.Tests;

/// <summary>
/// Pure Schema Migration rules shared by the workbench RPCs and the headless schema-prepare CLI:
/// the headless selection policy, definition normalisation/hashing and the compare diff.
/// </summary>
public sealed class SchemaMigrationRulesTests
{
    private const string ConstraintV2 = "CYB_CONSTRAINT_V2|{\"ConstraintKind\":\"FOREIGN_KEY\",\"IsSystemNamed\":false}";
    private const string SystemNamedPrimaryKeyV2 = "CYB_CONSTRAINT_V2|{\"ConstraintKind\":\"PRIMARY_KEY\",\"IsSystemNamed\":true}";
    private const string IndexV2 = "CYB_INDEX_V2|{\"IndexTypeId\":2}";
    private const string TableV2 = "CYB_TABLE_V2|{\"Columns\":[]}";

    [Fact]
    public void PlanHeadlessSelection_SelectsDeployableDifferentAndMissingInTargetRows()
    {
        var procedure = Row("StoredProcedure", "Different", definition: "CREATE PROCEDURE dbo.A AS SELECT 1");
        var view = Row("View", "MissingInTarget", definition: "CREATE VIEW dbo.B AS SELECT 1 AS X");
        var table = Row("Table", "Different", definition: TableV2, targetDefinition: TableV2);
        var index = Row("Index", "MissingInTarget", definition: IndexV2);
        var constraint = Row("Constraint", "Different", definition: ConstraintV2, targetDefinition: ConstraintV2);

        var plan = SchemaMigrationRules.PlanHeadlessSelection([procedure, view, table, index, constraint]);

        Assert.Equal([procedure, view, table, index, constraint], plan.Selected);
        Assert.Empty(plan.Skipped);
    }

    [Fact]
    public void PlanHeadlessSelection_NeverSelectsMissingInSourceEvenWhenDeployable()
    {
        // BuildSchemaComparisonRows marks target-only Constraint/Index rows deployable (declarative
        // removal), so IsDeployable alone must not drive headless selection.
        var constraintRemoval = Row("Constraint", "MissingInSource", definition: string.Empty, targetDefinition: ConstraintV2, isDeployable: true);
        var targetOnlyProcedure = Row("StoredProcedure", "MissingInSource", definition: string.Empty, isDeployable: false);

        var plan = SchemaMigrationRules.PlanHeadlessSelection([constraintRemoval, targetOnlyProcedure]);

        Assert.Empty(plan.Selected);
        var skipped = Assert.Single(plan.Skipped);
        Assert.Same(constraintRemoval, skipped.Row);
        Assert.Equal("TARGET_ONLY_NOT_AUTO_SELECTED", skipped.ReasonCode);
    }

    [Fact]
    public void PlanHeadlessSelection_IgnoresEqualRows()
    {
        var plan = SchemaMigrationRules.PlanHeadlessSelection([Row("View", "Equal", definition: "CREATE VIEW dbo.C AS SELECT 1 AS X", isDeployable: false)]);

        Assert.Empty(plan.Selected);
        Assert.Empty(plan.Skipped);
    }

    [Theory]
    [InlineData("TableType", "Different", "CREATE TYPE dbo.T AS TABLE (Id INT)", "CREATE TYPE dbo.T AS TABLE (Id BIGINT)", "MANUAL_RUNNER_REQUIRES_MIGRATION_SCRIPT")]
    [InlineData("Sequence", "Different", "CREATE SEQUENCE dbo.S", "CREATE SEQUENCE dbo.S START WITH 2", "MANUAL_RUNNER_REQUIRES_MIGRATION_SCRIPT")]
    [InlineData("Synonym", "MissingInTarget", "CREATE SYNONYM dbo.Y FOR dbo.Z", "", "MANUAL_RUNNER_UNMAPPED_OBJECT_TYPE")]
    [InlineData("Constraint", "MissingInTarget", "ALTER TABLE dbo.T ADD CONSTRAINT FK_X", "", "CONSTRAINT_SNAPSHOT_REQUIRES_REFRESH")]
    [InlineData("Index", "MissingInTarget", "CREATE INDEX IX_X ON dbo.T (Id)", "", "INDEX_SNAPSHOT_REQUIRES_REFRESH")]
    [InlineData("Table", "Different", "CREATE TABLE dbo.T (Id INT)", TableV2, "TABLE_SNAPSHOT_REQUIRES_REFRESH")]
    [InlineData("Constraint", "MissingInTarget", SystemNamedPrimaryKeyV2, "", "SYSTEM_NAMED_CONSTRAINT_REQUIRES_EXPLICIT_NAME")]
    public void PlanHeadlessSelection_SkipsRowsThatValidationWouldFail(
        string objectType,
        string differenceType,
        string sourceDefinition,
        string targetDefinition,
        string expectedIssueCode)
    {
        var row = Row(objectType, differenceType, definition: sourceDefinition, targetDefinition: targetDefinition);

        var plan = SchemaMigrationRules.PlanHeadlessSelection([row]);

        Assert.Empty(plan.Selected);
        var skipped = Assert.Single(plan.Skipped);
        Assert.Equal(expectedIssueCode, skipped.ReasonCode);
        Assert.False(string.IsNullOrWhiteSpace(skipped.Reason));

        // Parity: the same row, validated as a saved selection, is a Fail with the same code.
        var issue = Assert.Single(SchemaMigrationRules.BuildSchemaValidationIssues([row], hasComparisonRows: true));
        Assert.Equal("Fail", issue.Severity);
        Assert.Equal(expectedIssueCode, issue.IssueCode);
    }

    [Fact]
    public void PlanHeadlessSelection_SelectionAlwaysValidatesWithoutFailures()
    {
        var rows = new[]
        {
            Row("StoredProcedure", "Different", definition: "CREATE PROCEDURE dbo.A AS SELECT 1"),
            Row("TableType", "Different", definition: "CREATE TYPE dbo.T AS TABLE (Id INT)", targetDefinition: "CREATE TYPE dbo.T AS TABLE (Id BIGINT)"),
            Row("Constraint", "MissingInSource", definition: string.Empty, targetDefinition: ConstraintV2, isDeployable: true),
            Row("Index", "MissingInTarget", definition: IndexV2)
        };

        var plan = SchemaMigrationRules.PlanHeadlessSelection(rows);
        var issues = SchemaMigrationRules.BuildSchemaValidationIssues(plan.Selected, hasComparisonRows: true);

        Assert.Equal(2, plan.Selected.Count);
        Assert.DoesNotContain(issues, x => x.Severity == "Fail");
    }

    [Fact]
    public void NormalizeSchemaDefinition_IgnoresCaseWhitespaceBracketsCommentsAndCreateAlterSpelling()
    {
        const string created = "CREATE PROCEDURE [dbo].[Sample]\r\nAS\r\n    -- comment\r\n    SELECT 1 /* block */;";
        const string altered = "create or alter procedure dbo.Sample as select 1;";

        Assert.Equal(
            SchemaMigrationRules.NormalizeSchemaDefinition(created),
            SchemaMigrationRules.NormalizeSchemaDefinition(altered));
        Assert.Equal(
            SchemaMigrationRules.ComputeSchemaHash(SchemaMigrationRules.NormalizeSchemaDefinition(created)),
            SchemaMigrationRules.ComputeSchemaHash(SchemaMigrationRules.NormalizeSchemaDefinition(altered)));
    }

    [Fact]
    public void NormalizeSchemaDefinition_PreservesStringLiteralContent()
    {
        Assert.NotEqual(
            SchemaMigrationRules.NormalizeSchemaDefinition("SELECT 'a b'"),
            SchemaMigrationRules.NormalizeSchemaDefinition("SELECT 'A B'"));
        Assert.Equal(string.Empty, SchemaMigrationRules.NormalizeSchemaDefinition("   "));
    }

    [Fact]
    public void ComputeSchemaHash_IsUppercaseSha256Hex()
    {
        // SHA-256 of the empty string.
        Assert.Equal(
            "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855",
            SchemaMigrationRules.ComputeSchemaHash(string.Empty));
    }

    [Fact]
    public void RemoveOperationalSchemaBindingClause_RemovesOnlyExecutableClause()
    {
        const string definition = "CREATE VIEW dbo.V WITH SCHEMABINDING AS SELECT 'WITH SCHEMABINDING' AS X -- WITH SCHEMABINDING";

        var result = SchemaMigrationRules.RemoveOperationalSchemaBindingClause(definition);

        Assert.Equal("CREATE VIEW dbo.V  AS SELECT 'WITH SCHEMABINDING' AS X -- WITH SCHEMABINDING", result);
    }

    [Fact]
    public void BuildSchemaComparisonRows_ClassifiesDifferencesAndHonoursExclusions()
    {
        var source = new[]
        {
            Snapshot("StoredProcedure", "Same", "CREATE PROCEDURE dbo.Same AS SELECT 1"),
            Snapshot("StoredProcedure", "Changed", "CREATE PROCEDURE dbo.Changed AS SELECT 1"),
            Snapshot("StoredProcedure", "New", "CREATE PROCEDURE dbo.New AS SELECT 1"),
            Snapshot("StoredProcedure", "Excluded", "CREATE PROCEDURE dbo.Excluded AS SELECT 1")
        };
        var target = new[]
        {
            Snapshot("StoredProcedure", "Same", "create or alter procedure dbo.Same as select 1"),
            Snapshot("StoredProcedure", "Changed", "CREATE PROCEDURE dbo.Changed AS SELECT 2"),
            Snapshot("Constraint", "FK_TargetOnly", ConstraintV2, parent: "T"),
            Snapshot("Trigger", "tg_T_RecordHistory", "CREATE TRIGGER dbo.tg_T_RecordHistory ON dbo.T AFTER UPDATE AS SELECT 1", parent: "T")
        };
        var excluded = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "STOREDPROCEDURE|DBO|EXCLUDED|" };

        var rows = SchemaMigrationRules.BuildSchemaComparisonRows(source, target, excluded)
            .ToDictionary(x => x.ObjectName);

        Assert.Equal(["Changed", "FK_TargetOnly", "New", "Same"], rows.Keys.Order(StringComparer.Ordinal));
        Assert.Equal("Equal", rows["Same"].DifferenceType);
        Assert.False(rows["Same"].IsDeployable);
        Assert.Equal("Different", rows["Changed"].DifferenceType);
        Assert.True(rows["Changed"].IsDeployable);
        Assert.Equal("MissingInTarget", rows["New"].DifferenceType);
        Assert.True(rows["New"].IsDeployable);
        Assert.Equal("MissingInSource", rows["FK_TargetOnly"].DifferenceType);
        Assert.True(rows["FK_TargetOnly"].IsDeployable);
        Assert.True(rows["FK_TargetOnly"].IsDestructiveRisk);
    }

    [Theory]
    [InlineData(0, true)]
    [InlineData(25, true)]
    [InlineData(26, false)]
    public void SchemaPrepare_ReusesAcceptedRunOnlyWithinTwentyFiveMinutes(int ageMinutes, bool expected)
    {
        var now = new DateTime(2026, 10, 13, 12, 0, 0, DateTimeKind.Utc);

        Assert.Equal(expected, SchemaMigrationCli.IsWithinReuseWindow(now.AddMinutes(-ageMinutes), now));
        Assert.False(SchemaMigrationCli.IsWithinReuseWindow(null, now));
    }

    [Fact]
    public async Task SchemaPrepare_MissingRequiredArgumentIsUsageError()
    {
        Assert.Equal(4, await SchemaMigrationCli.RunAsync([], CancellationToken.None));
        Assert.Equal(4, await SchemaMigrationCli.RunAsync(["schema-unknown"], CancellationToken.None));
        Assert.Equal(4, await SchemaMigrationCli.RunAsync(["schema-prepare", "--target-server", "s"], CancellationToken.None));
    }

    private static SchemaComparisonRowRecord Row(
        string objectType,
        string differenceType,
        string definition,
        string targetDefinition = "",
        bool isDeployable = true) =>
        new()
        {
            ComparisonGuid = Guid.NewGuid().ToString(),
            ObjectType = objectType,
            SchemaName = "dbo",
            ObjectName = $"{objectType}_{differenceType}",
            ParentObjectName = objectType is "Constraint" or "Index" ? "T" : string.Empty,
            DifferenceType = differenceType,
            IsDeployable = isDeployable,
            SourceDefinition = definition,
            TargetDefinition = targetDefinition
        };

    private static SchemaObjectSnapshot Snapshot(string objectType, string name, string definition, string parent = "")
    {
        var normalized = SchemaMigrationRules.NormalizeSchemaDefinition(definition);
        var hash = SchemaMigrationRules.ComputeSchemaHash(normalized);
        return new SchemaObjectSnapshot(objectType, "dbo", name, parent, definition, hash, hash, false);
    }
}
