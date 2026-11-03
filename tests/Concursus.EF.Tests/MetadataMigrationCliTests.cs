using System.Text.RegularExpressions;
using Concursus.EF.MigrationCli;
using Xunit;

namespace Concursus.EF.Tests;

/// <summary>
/// metadata-auto (Publish-CymBuildServer.ps1) selects every staged Insert/Update row that the
/// apply step can handle. Selecting a row in a table with no handler fails both
/// MetadataValidate_Run and MetadataApply_Run, so the C# allowlist must match the SQL one.
/// </summary>
public sealed class MetadataMigrationCliTests
{
    [Theory]
    [InlineData("SCore", "EntityProperties", "Insert", 1, false, true)]
    [InlineData("SCore", "EntityProperties", "Update", null, false, true)]
    [InlineData("SUserInterface", "GridViewColumnDefinitions", "Update", 1, false, true)]
    [InlineData("SJob", "MilestoneTypes", "Insert", 1, false, true)]
    [InlineData("SCore", "EntityProperties", "NoChange", 1, false, false)]
    [InlineData("SCore", "EntityProperties", "Update", 254, false, false)] // retirement
    [InlineData("SCore", "EntityProperties", "Insert", 1, true, false)]    // ignored
    [InlineData("SUserInterface", "MainMenuItems", "Insert", 1, false, false)] // no apply handler
    [InlineData("SCore", "Languages", "Update", 1, false, false)]              // no apply handler
    public void IsAutoSelectable_MatchesApplyRules(string schema, string table, string differenceType, int? sourceRowStatus, bool isIgnored, bool expected)
    {
        Assert.Equal(expected, MetadataMigrationCli.IsAutoSelectable(schema, table, differenceType, sourceRowStatus, isIgnored));
    }

    [Fact]
    public void HandledTables_MatchTheValidateProcAllowlist()
    {
        var proc = File.ReadAllText(FindRepoFile("Database", "CymBuild_DB", "Schema", "Programmability", "Procedures", "SMigration.MetadataValidate_Run.sql"));
        var block = proc[proc.IndexOf("N'UnsupportedApplyHandler',", proc.IndexOf("INSERT INTO SMigration.Metadata_ValidationIssues", StringComparison.Ordinal), StringComparison.Ordinal)..];
        block = block[..block.IndexOf("GROUP BY", StringComparison.Ordinal)];

        var sqlTables = Regex.Matches(block, @"tr\.SchemaName = N'(?<schema>\w+)' AND tr\.TableName IN\s*\((?<tables>[^)]*)\)")
            .SelectMany(m => Regex.Matches(m.Groups["tables"].Value, @"N'(\w+)'").Select(t => (m.Groups["schema"].Value, t.Groups[1].Value)))
            .OrderBy(t => t.Item1).ThenBy(t => t.Item2)
            .ToArray();

        var cliTables = MetadataMigrationCli.HandledTables.OrderBy(t => t.Schema).ThenBy(t => t.Table).ToArray();

        Assert.NotEmpty(sqlTables);
        Assert.Equal(sqlTables, cliTables);
    }

    [Theory]
    [InlineData(@"10.100.34.114\general", @"10.100.34.114\general", true)]   // DEV -> QA
    [InlineData(@"10.100.34.114\general", @" 10.100.34.114/GENERAL ", true)]
    [InlineData(@"10.100.34.114\general", @"SOC-SQLBRE01\SQL2022", false)]   // QA -> UAT (CYB-584)
    [InlineData("", @"SOC-SQLBRE01\SQL2022", false)]
    public void IsSameSqlServer_MatchesTheApiRule(string source, string target, bool expected)
    {
        Assert.Equal(expected, MetadataMigrationCli.IsSameSqlServer(source, target));
    }

    [Fact]
    public void CreatedRun_StagesAcrossServersLikeTheWorkbench_AndFailsOnStagingIssues()
    {
        // CYB-584: QA -> UAT staged zero rows (three-part names cannot reach another server) and
        // metadata-auto reported "nothing-to-do". Across servers it must stage and sync the
        // identity-map registry over two connections, as the API does, and fail whenever staging
        // recorded Fail issues.
        var cli = File.ReadAllText(FindRepoFile("libs", "Concursus.EF", "MigrationCli", "MetadataMigrationCli.cs")).Replace("\r\n", "\n");
        var api = File.ReadAllText(FindRepoFile("services", "Concursus.API", "Services", "CoreService.MetadataMigration.cs")).Replace("\r\n", "\n");

        Assert.Contains("var sameServer = IsSameSqlServer(o.SourceServer, o.TargetServer);", cli, StringComparison.Ordinal);
        Assert.Contains("await MetadataTwoConnectionStaging.StageMetadataWithTwoConnectionsAsync(source, target, runGuid, includeRetirements: false, ct)", cli, StringComparison.Ordinal);
        Assert.Contains("await MetadataTwoConnectionStaging.SyncMetadataRegistryFromEntityTypesAsync(source, target, runGuid, ct)", cli, StringComparison.Ordinal);
        Assert.Contains("new SqlParameter(\"@SkipRegistrySync\", SqlDbType.Bit) { Value = true }", cli, StringComparison.Ordinal);

        var stage = cli.IndexOf("\"SMigration.MetadataStage_Run\"", StringComparison.Ordinal);
        var stageCheck = cli.IndexOf("var stageFailures = await ReadFailIssuesAsync(target, runGuid, ct)", StringComparison.Ordinal);
        var readStaged = cli.IndexOf("var staged = await ReadActionableStagedRowsAsync(target, runGuid, ct)", StringComparison.Ordinal);
        Assert.True(stage < stageCheck && stageCheck < readStaged, "Staging failures must be checked before reading staged rows.");

        // One implementation: the API uses the same shared class, not its own copy.
        Assert.Contains("using static Concursus.EF.MetadataMigration.MetadataTwoConnectionStaging;", api, StringComparison.Ordinal);
        Assert.DoesNotContain("private static async Task StageMetadataWithTwoConnectionsAsync(", api, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaPrepare_RefreshedRunWithNothingSelected_PreparesANewRunInsteadOfFailing()
    {
        // CYB-584, 2026-10-16 UAT: a stale accepted run whose selected objects no longer differed was
        // re-validated with nothing selected (NO_SELECTED_ROWS) and blocked the metadata step.
        var cli = File.ReadAllText(FindRepoFile("libs", "Concursus.EF", "MigrationCli", "SchemaMigrationCli.cs")).Replace("\r\n", "\n");

        var refreshed = cli.IndexOf("report.Mode = \"refreshed\";", StringComparison.Ordinal);
        var fill = cli.IndexOf("await FillFromRunAsync(engine, options, existing.RunGuid, report, ct)", refreshed, StringComparison.Ordinal);
        var guard = cli.IndexOf("if (report.Selected.Count > 0)", refreshed, StringComparison.Ordinal);
        var validate = cli.IndexOf("ValidateAndAcceptAsync(", refreshed, StringComparison.Ordinal);
        var created = cli.IndexOf("report.Mode = \"created\";", refreshed, StringComparison.Ordinal);

        Assert.True(refreshed > 0 && fill > refreshed && guard > fill && validate > guard && created > validate,
            "A refreshed run must only be revalidated while it still has a selection; otherwise fall through to a new run.");
    }

    [Fact]
    public void ParseArguments_StoresEachValueUnderItsOwnKey()
    {
        // Regression: args[++i] was evaluated before the key was read, so values were stored under themselves.
        var parsed = MetadataMigrationCli.ParseArguments(
            ["--target-server", @"10.100.34.114\general", "--target-database", "CymBuild_QA2", "--verbose", "--OUT", "r.json"]);

        Assert.Equal(@"10.100.34.114\general", parsed["--target-server"]);
        Assert.Equal("CymBuild_QA2", parsed["--target-database"]);
        Assert.Equal("true", parsed["--verbose"]);
        Assert.Equal("r.json", parsed["--out"]);
        Assert.False(parsed.ContainsKey("CymBuild_QA2"));
    }

    [Fact]
    public void ConnectionStringConfiguration_ExposesDefaultConnection()
    {
        var configuration = ConnectionStringConfiguration.ForIntegratedSecurity(@"server\inst", "Db");
        var connection = Microsoft.Extensions.Configuration.ConfigurationExtensions.GetConnectionString(configuration, "DefaultConnection");

        Assert.Contains(@"Data Source=server\inst", connection, StringComparison.Ordinal);
        Assert.Contains("Integrated Security=True", connection, StringComparison.Ordinal);
        Assert.Null(Microsoft.Extensions.Configuration.ConfigurationExtensions.GetConnectionString(configuration, "Other"));
    }

    private static string FindRepoFile(params string[] segments)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "CymBuild.Monorepo.sln")))
        {
            directory = directory.Parent;
        }

        return Path.Combine([directory?.FullName ?? throw new InvalidOperationException("Repository root not found."), .. segments]);
    }
}
