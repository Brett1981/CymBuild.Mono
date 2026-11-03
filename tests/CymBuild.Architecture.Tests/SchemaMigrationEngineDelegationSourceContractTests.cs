using Xunit;

namespace CymBuild.Architecture.Tests;

// The Schema Migration workbench RPCs and the headless schema-prepare CLI must run one
// implementation of create/compare/select/validate/accept, so a run prepared by the deploy script is
// indistinguishable from one prepared in the UI. CoreService keeps the gRPC surface (auth, request
// validation, status mapping, proto shaping) and delegates everything else to
// libs/Concursus.EF/SchemaMigration.
public sealed class SchemaMigrationEngineDelegationSourceContractTests
{
    private static readonly string[] EngineOnlyMembers =
    [
        "BuildSchemaComparisonRows(",
        "BuildSchemaValidationIssues(",
        "NormalizeSchemaDefinition(",
        "RemoveOperationalSchemaBindingClause(",
        "ComputeSchemaHash(",
        "ReadSchemaSnapshotAsync(",
        "ReadSchemaNewTableCaptureJsonAsync(",
        "SynchronizeSchemaExclusionsAsync(",
        "ExecuteSchemaMaintenanceProcedureAsync(",
        "InsertSchemaComparisonRowAsync(",
        "InsertSchemaSelectionRowAsync(",
        "class SchemaSnapshotSql",
        "public const string Tables = @\"",
        "INSERT INTO SMigration.Schema_Run",
        "IsReviewed = 1,"
    ];

    [Fact]
    public void CoreService_DelegatesWorkbenchStepsToTheSharedEngine()
    {
        var service = ReadRepositoryFile("services", "Concursus.API", "Services", "CoreService.SchemaMigration.cs");

        Assert.Contains("await SchemaEngine.CreateRunAsync(", service, StringComparison.Ordinal);
        Assert.Contains("await SchemaEngine.CompareAsync(", service, StringComparison.Ordinal);
        Assert.Contains("enforceSourceSyncGate: true", service, StringComparison.Ordinal);
        Assert.Contains("await SchemaEngine.SaveSelectionAsync(", service, StringComparison.Ordinal);
        Assert.Contains("await SchemaEngine.ValidateAsync(", service, StringComparison.Ordinal);
        Assert.Contains("await SchemaEngine.AcceptAsync(", service, StringComparison.Ordinal);
        Assert.Contains(
            "new SchemaMigrationEngine(ResolveSqlConnectionString(), _migrationBootstrapRepository)",
            service,
            StringComparison.Ordinal);

        foreach (var member in EngineOnlyMembers)
        {
            Assert.DoesNotContain(member, service, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void Engine_HoldsExactlyOneCopyOfEachWorkbenchHelper()
    {
        var engineSources = Directory
            .GetFiles(RepositoryLayout.PathFromRoot("libs", "Concursus.EF", "SchemaMigration"), "*.cs")
            .Select(File.ReadAllText)
            .ToArray();
        var engine = string.Join("\n", engineSources);

        foreach (var declaration in new[]
        {
            "public static List<SchemaComparisonDraft> BuildSchemaComparisonRows(",
            "public static List<SchemaValidationDraft> BuildSchemaValidationIssues(",
            "public static string NormalizeSchemaDefinition(string definition)",
            "public static string RemoveOperationalSchemaBindingClause(string definition)",
            "public static string ComputeSchemaHash(string value)",
            "public static async Task<List<SchemaObjectSnapshot>> ReadSchemaSnapshotAsync(",
            "public static class SchemaSnapshotSql"
        })
        {
            Assert.Equal(1, CountOccurrences(engine, declaration));
        }

        // The engine stays free of the gRPC/ASP.NET host so the CLI can construct it from IConfiguration.
        Assert.DoesNotContain("Grpc.Core", engine, StringComparison.Ordinal);
        Assert.DoesNotContain("RpcException", engine, StringComparison.Ordinal);
        Assert.DoesNotContain("HttpContext", engine, StringComparison.Ordinal);
    }

    [Fact]
    public void HeadlessCli_PreparesThroughTheEngineAndNeverAutoSelectsTargetOnlyRows()
    {
        var cli = ReadRepositoryFile("libs", "Concursus.EF", "MigrationCli", "SchemaMigrationCli.cs");
        var rules = ReadRepositoryFile("libs", "Concursus.EF", "SchemaMigration", "SchemaMigrationRules.cs");

        Assert.Contains("\"schema-prepare\"", cli, StringComparison.Ordinal);
        Assert.Contains("FindAcceptedUnappliedRunAsync(", cli, StringComparison.Ordinal);
        Assert.Contains("enforceSourceSyncGate: false", cli, StringComparison.Ordinal);
        Assert.Contains("SchemaMigrationRules.PlanHeadlessSelection(", cli, StringComparison.Ordinal);
        Assert.Contains("TimeSpan.FromMinutes(25)", cli, StringComparison.Ordinal);
        Assert.DoesNotContain("EnsureSchemaWorkbenchAsync", cli, StringComparison.Ordinal);

        var planner = rules[rules.IndexOf("public static SchemaHeadlessSelectionPlan PlanHeadlessSelection(", StringComparison.Ordinal)..];
        Assert.Contains("BuildSchemaValidationIssues([row], hasComparisonRows: true)", planner, StringComparison.Ordinal);
        Assert.Contains("\"TARGET_ONLY_NOT_AUTO_SELECTED\"", planner, StringComparison.Ordinal);
    }

    private static int CountOccurrences(string text, string value)
    {
        var count = 0;
        var index = 0;
        while ((index = text.IndexOf(value, index, StringComparison.Ordinal)) >= 0)
        {
            count++;
            index += value.Length;
        }

        return count;
    }

    private static string ReadRepositoryFile(params string[] segments) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(segments));
}
