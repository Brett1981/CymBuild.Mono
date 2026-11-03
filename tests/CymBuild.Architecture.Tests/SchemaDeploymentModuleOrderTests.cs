using System.Diagnostics;
using Xunit;

namespace CymBuild.Architecture.Tests;

// 2026-10-10, UAT_Test run 99bdd9e8: the runner applied every Function before every View by type
// rank alone, so SJob.tvf_JobFeeDrawdown (reading the new SJob.Job_FeeDrawdown.Variation column)
// failed with "Invalid column name 'Variation'" before the view was deployed. These tests run the
// runner's own ordering functions under PowerShell against fixture source files.
public sealed class SchemaDeploymentModuleOrderTests
{
    private const string RunnerHarness = """
        $ErrorActionPreference = 'Stop'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($env:CYMBUILD_RUNNER_PATH, [ref]$null, [ref]$null)
        foreach ($name in 'Get-CymBuildApplyItemRank', 'Get-CymBuildSqlTwoPartReferenceKeys', 'Get-CymBuildOrderedApplyItems') {
            $definition = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
            if ($null -eq $definition) { throw "Runner function $name was not found." }
            . ([scriptblock]::Create($definition.Extent.Text))
        }
        $items = @(Import-Csv -LiteralPath $env:CYMBUILD_ITEMS_PATH)
        Get-CymBuildOrderedApplyItems -Items $items 3>$null | ForEach-Object { "ORDER|$($_.ObjectType) $($_.SchemaName).$($_.ObjectName)" }
        """;

    [Fact]
    public void ApplyOrder_PutsEachModuleAfterTheSelectedModulesItReferences()
    {
        using var fixture = new SourceFixture();
        fixture.Add("Table", "SDemo", "Things", "CREATE TABLE SDemo.Things (ID int NOT NULL);");
        fixture.Add("Index", "SDemo", "IX_Things_ID", "CREATE INDEX IX_Things_ID ON SDemo.Things (ID);", parentObjectName: "Things");
        fixture.Add("Function", "SDemo", "tvf_ReadsView",
            "CREATE OR ALTER FUNCTION SDemo.tvf_ReadsView() RETURNS TABLE AS RETURN SELECT v.NewColumn FROM [SDemo].[vw_NewColumn] AS v;");
        fixture.Add("View", "SDemo", "vw_NewColumn", "CREATE OR ALTER VIEW SDemo.vw_NewColumn AS SELECT ID AS NewColumn FROM SDemo.Things;");
        fixture.Add("View", "SDemo", "vw_ReadsFunction", "CREATE OR ALTER VIEW SDemo.vw_ReadsFunction AS SELECT h.ID FROM SDemo.tvf_Helper() AS h;");
        fixture.Add("Function", "SDemo", "tvf_Helper", "CREATE OR ALTER FUNCTION SDemo.tvf_Helper() RETURNS TABLE AS RETURN SELECT ID FROM SDemo.Things;");
        fixture.Add("Function", "SDemo", "tvf_CommentOnly",
            "-- Source schema hash: SDemo.vw_Zeta\n/* SDemo.vw_Zeta */\nCREATE OR ALTER FUNCTION SDemo.tvf_CommentOnly() RETURNS TABLE AS RETURN SELECT 1 AS One;");
        fixture.Add("View", "SDemo", "vw_Zeta", "CREATE OR ALTER VIEW SDemo.vw_Zeta AS SELECT 1 AS One;");

        Assert.Equal(
            [
                "Table SDemo.Things",
                "Function SDemo.tvf_CommentOnly",
                "Function SDemo.tvf_Helper",
                "View SDemo.vw_NewColumn",
                "Function SDemo.tvf_ReadsView",
                "View SDemo.vw_ReadsFunction",
                "View SDemo.vw_Zeta",
                "Index SDemo.IX_Things_ID",
            ],
            RunOrdering(fixture));
    }

    [Fact]
    public void ApplyOrder_FallsBackToTypeRankForAReferenceCycle()
    {
        using var fixture = new SourceFixture();
        fixture.Add("View", "SDemo", "vw_A", "CREATE OR ALTER VIEW SDemo.vw_A AS SELECT ID FROM SDemo.tvf_B();");
        fixture.Add("Function", "SDemo", "tvf_B", "CREATE OR ALTER FUNCTION SDemo.tvf_B() RETURNS TABLE AS RETURN SELECT ID FROM SDemo.vw_A;");

        Assert.Equal(["Function SDemo.tvf_B", "View SDemo.vw_A"], RunOrdering(fixture));
    }

    [Fact]
    public void Runner_UsesTheReferenceAwareOrderForPreviewAndApply()
    {
        var runner = File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1"]));

        Assert.Contains("$orderedApplyItems = @(Get-CymBuildOrderedApplyItems -Items $SupportedItems)", runner, StringComparison.Ordinal);
        Assert.Contains("$orderedApplyItems = @(Get-CymBuildOrderedApplyItems -Items $supported)", runner, StringComparison.Ordinal);
        Assert.DoesNotContain("elseif ($_.ObjectType -eq \"Function\") { 490 }", runner, StringComparison.Ordinal);
    }

    private static IReadOnlyList<string> RunOrdering(SourceFixture fixture)
    {
        var harnessPath = Path.Combine(fixture.Directory, "harness.ps1");
        File.WriteAllText(harnessPath, RunnerHarness);

        var startInfo = new ProcessStartInfo(ResolvePowerShellExecutable())
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        };
        foreach (var argument in new[] { "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", harnessPath })
        {
            startInfo.ArgumentList.Add(argument);
        }

        startInfo.Environment["CYMBUILD_RUNNER_PATH"] = RepositoryLayout.PathFromRoot(
            ["tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1"]);
        startInfo.Environment["CYMBUILD_ITEMS_PATH"] = fixture.WriteItemsCsv();

        using var process = Process.Start(startInfo)
            ?? throw new InvalidOperationException("PowerShell could not be started.");
        var standardError = process.StandardError.ReadToEndAsync();
        var standardOutput = process.StandardOutput.ReadToEnd();
        process.WaitForExit();

        Assert.True(process.ExitCode == 0, $"PowerShell exited {process.ExitCode}: {standardError.Result}");

        return standardOutput
            .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
            .Where(line => line.StartsWith("ORDER|", StringComparison.Ordinal))
            .Select(line => line["ORDER|".Length..])
            .ToArray();
    }

    private static string ResolvePowerShellExecutable()
    {
        var pathVariable = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        var extensions = OperatingSystem.IsWindows() ? new[] { ".exe", string.Empty } : new[] { string.Empty };
        foreach (var candidate in new[] { "pwsh", "powershell" })
        {
            foreach (var directory in pathVariable.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
            {
                if (extensions.Any(extension => File.Exists(Path.Combine(directory, candidate + extension))))
                {
                    return candidate;
                }
            }
        }

        throw new InvalidOperationException("Neither 'pwsh' nor 'powershell' was found on PATH; the schema runner ordering cannot be tested.");
    }

    private sealed class SourceFixture : IDisposable
    {
        private readonly List<string> _rows = ["\"ObjectType\",\"SchemaName\",\"ObjectName\",\"ParentObjectName\",\"ConstraintKind\",\"SourceFile\""];

        public string Directory { get; } = System.IO.Directory.CreateTempSubdirectory("cymbuild-module-order-").FullName;

        public void Add(string objectType, string schemaName, string objectName, string sql, string parentObjectName = "")
        {
            var sourceFile = Path.Combine(Directory, $"{objectType}.{schemaName}.{objectName}.sql");
            File.WriteAllText(sourceFile, sql);
            _rows.Add($"\"{objectType}\",\"{schemaName}\",\"{objectName}\",\"{parentObjectName}\",\"\",\"{sourceFile}\"");
        }

        public string WriteItemsCsv()
        {
            var path = Path.Combine(Directory, "items.csv");
            File.WriteAllLines(path, _rows);
            return path;
        }

        public void Dispose() => System.IO.Directory.Delete(Directory, recursive: true);
    }
}
