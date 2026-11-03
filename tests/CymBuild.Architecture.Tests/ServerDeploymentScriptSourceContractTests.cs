using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// tools/Deployment/Publish-CymBuildServer.ps1 deploys the API and PWA to the QA IIS host.
/// These guard the safety properties the script was approved with: QA only, server-owned
/// configuration never overwritten, schema applied through the controlled runner from
/// committed files only, and no secrets in source.
/// </summary>
public sealed class ServerDeploymentScriptSourceContractTests
{
    private static readonly Lazy<string> Script = new(() =>
        File.ReadAllText(RepositoryLayout.PathFromRoot("tools", "Deployment", "Publish-CymBuildServer.ps1")));

    [Fact]
    public void Script_TargetsQaAndUatButNeverLive()
    {
        var environmentSet = Regex.Match(Script.Value, @"\[ValidateSet\(([^)]*)\)\]\s*\[string\]\$Environment");
        Assert.True(environmentSet.Success, "Environment parameter must be constrained by ValidateSet.");
        Assert.Equal("'QA', 'UAT'", environmentSet.Groups[1].Value.Trim());

        var targetKeys = Regex.Matches(Script.Value, @"^    (?<name>\w+)\s*=\s*@\{", RegexOptions.Multiline).Select(m => m.Groups["name"].Value).ToArray();
        Assert.Equal(["QA", "UAT"], targetKeys);
        Assert.DoesNotContain(@"C:\Program Files\Concursus.API'", Script.Value, StringComparison.Ordinal);
        Assert.DoesNotContain(@"C:\inetpub\wwwroot\Concursus.PWA'", Script.Value, StringComparison.Ordinal);
        Assert.DoesNotContain("'Concursus.API'", Script.Value, StringComparison.Ordinal);
        Assert.DoesNotContain("'Concursus.PWA'", Script.Value, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("appsettings.QA.json")]
    [InlineData("appsettings.Development.json")]
    [InlineData("appsettings.Test.json")]
    public void DatabaseNames_ComeFromCommittedEnvironmentAppSettings(string appSettings)
    {
        // Database names change between releases; they must not be hard-coded in the scripts.
        Assert.DoesNotMatch(new Regex(@"^\s*(DatabaseServer|TargetDatabase|SourceDatabase)\s*=", RegexOptions.Multiline), Script.Value);
        var readme = File.ReadAllText(RepositoryLayout.PathFromRoot("tools", "Deployment", "README.md"));
        foreach (var source in new[] { Script.Value, DatabaseScript.Value, readme })
        {
            Assert.DoesNotMatch(new Regex(@"CymBuild_(QA\d*|DEV\d*|UAT\w*)\b|10\.100\.\d+\.\d+|SOC-SQL\w+", RegexOptions.IgnoreCase), source);
        }
        Assert.DoesNotContain("'--source-environment', 'DEV'", DatabaseScript.Value, StringComparison.Ordinal);

        Assert.Contains($"'{appSettings}'", Script.Value, StringComparison.Ordinal);
        var json = File.ReadAllText(RepositoryLayout.PathFromRoot("services", "Concursus.API", appSettings));
        Assert.Matches(new Regex("\"(DefaultConnection|ShoreDB|CymBuild)\"\\s*:\\s*\"[^\"]*Initial Catalog=(?!Concursus;)[^\"]+\""), json);
    }

    [Fact]
    public void DatabaseResolver_UsesTheApiConnectionStringOrderAndRefusesLive()
    {
        var program = File.ReadAllText(RepositoryLayout.PathFromRoot("services", "Concursus.API", "Program.cs"));
        var apiOrder = Regex.Matches(program, @"GetConnectionString\(""(\w+)""\)").Select(m => m.Groups[1].Value).Distinct().Take(3);
        Assert.Equal(["DefaultConnection", "ShoreDB", "CymBuild"], apiOrder);
        Assert.Contains("foreach ($key in 'DefaultConnection', 'ShoreDB', 'CymBuild')", DatabaseScript.Value, StringComparison.Ordinal);

        var resolve = DatabaseScript.Value[DatabaseScript.Value.IndexOf("function Resolve-CymBuildDeployDatabases", StringComparison.Ordinal)..];
        Assert.Contains("Test-CymBuildLiveDatabaseName", resolve, StringComparison.Ordinal);
        Assert.Contains("source and target must differ", resolve, StringComparison.Ordinal);
    }

    [Fact]
    public void Script_NeverOverwritesServerOwnedConfiguration()
    {
        Assert.Contains("$ServerOwnedFilePatterns = @('appsettings*.json', 'web.config', 'nlog.config')", Script.Value, StringComparison.Ordinal);
        Assert.Contains("$ServerOwnedDirectories = @('logs')", Script.Value, StringComparison.Ordinal);

        // Every mirror into a live folder must keep server-owned files.
        var liveMirrors = Regex.Matches(Script.Value, @"Invoke-Mirror\s+\S+\s+\$Cfg\.(Api|Pwa)\.Path(?<rest>[^\r\n]*)");
        Assert.NotEmpty(liveMirrors);
        Assert.All(liveMirrors, m => Assert.Contains("-KeepServerOwned", m.Groups["rest"].Value, StringComparison.Ordinal));
    }

    [Fact]
    public void Script_RequiresConfirmationAndSupportsWhatIf()
    {
        Assert.Contains("SupportsShouldProcess = $true, ConfirmImpact = 'High'", Script.Value, StringComparison.Ordinal);
        Assert.Contains("$PSCmdlet.ShouldProcess(", Script.Value, StringComparison.Ordinal);
    }

    [Fact]
    public void Script_RefusesUncommittedSource()
    {
        Assert.Contains("'status', '--porcelain'", Script.Value, StringComparison.Ordinal);
        Assert.Contains("Working tree has uncommitted changes", Script.Value, StringComparison.Ordinal);
    }

    private static readonly Lazy<string> DatabaseScript = new(() =>
        File.ReadAllText(RepositoryLayout.PathFromRoot("tools", "Deployment", "CymBuildDatabaseDeploy.ps1")));

    [Fact]
    public void DatabasePhase_AppliesSchemaThroughControlledRunnerFromCommittedFiles()
    {
        var db = DatabaseScript.Value;
        Assert.Contains(@"tools\SchemaDeployment\Invoke-CymBuildSchemaDeployment.ps1", db, StringComparison.Ordinal);

        // Sync the selected definitions, commit them, then apply: the runner only applies committed files.
        var sync = db.IndexOf("@('-SyncSource', '-AllowNonDevSource')", StringComparison.Ordinal);
        var commit = db.IndexOf("git -C $RepoRoot commit", StringComparison.Ordinal);
        var apply = db.IndexOf("'-Apply', '-SkipSourceMaterialization'", StringComparison.Ordinal);
        Assert.True(sync >= 0 && commit > sync && apply > commit, "Schema must sync, then commit, then apply.");

        Assert.DoesNotContain("-AllowLive", db, StringComparison.Ordinal);
        Assert.DoesNotContain("-IgnoreTargetMismatch", db, StringComparison.Ordinal);
        Assert.DoesNotContain("-RetryFailedDeployment", db, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaSync_FromNonDevSource_NeverCommitsAndFailsOnDrift()
    {
        var db = DatabaseScript.Value;
        var step = db[db.IndexOf("function Invoke-CymBuildSchemaStep", StringComparison.Ordinal)..];

        // A non-DEV source that differs from committed source is discarded and fails, before any commit.
        var guard = step.IndexOf("if ($staged -and $SourceEnvironment -ne 'DEV')", StringComparison.Ordinal);
        var commit = step.IndexOf("git -C $RepoRoot commit", StringComparison.Ordinal);
        Assert.True(guard >= 0 && commit > guard, "The non-DEV drift guard must run before the sync commit.");

        var guardBody = step[guard..commit];
        Assert.Contains("checkout -q -- $schemaPath", guardBody, StringComparison.Ordinal);
        Assert.Contains("-Status Failed", guardBody, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaSync_ChangingAnApiEmbeddedFile_StopsBeforeApply()
    {
        var db = DatabaseScript.Value;
        var step = db[db.IndexOf("function Invoke-CymBuildSchemaStep", StringComparison.Ordinal)..];

        var check = step.IndexOf("if ($staleEmbedded.Count -gt 0)", StringComparison.Ordinal);
        var apply = step.IndexOf("'-Apply', '-SkipSourceMaterialization'", StringComparison.Ordinal);
        Assert.True(check >= 0 && apply > check, "A sync that changes an API-embedded file must stop before the apply.");
        Assert.Contains("Get-CymBuildEmbeddedSchemaFiles", step, StringComparison.Ordinal);

        // The bootstrap's metadata procedures are embedded by wildcard, so discovery must expand it.
        var csproj = File.ReadAllText(RepositoryLayout.PathFromRoot("libs", "Concursus.EF", "Concursus.EF.csproj"));
        Assert.Contains(@"Procedures\SMigration.Metadata*.sql", csproj, StringComparison.Ordinal);
        Assert.Contains("$pattern.Contains('*')", db, StringComparison.Ordinal);
    }

    [Fact]
    public void DatabasePhase_BacksUpBeforeSchemaAndRunsMetadataOnlyAfterSchema()
    {
        var db = DatabaseScript.Value;
        var phase = db[db.IndexOf("function Invoke-CymBuildDatabasePhase", StringComparison.Ordinal)..];

        var backup = phase.IndexOf("Invoke-CymBuildDatabaseBackup", StringComparison.Ordinal);
        var schema = phase.IndexOf("Invoke-CymBuildSchemaStep", StringComparison.Ordinal);
        var metadata = phase.IndexOf("Invoke-CymBuildMetadataStep", StringComparison.Ordinal);
        Assert.True(backup >= 0 && schema > backup && metadata > schema, "Order must be backup -> schema -> metadata.");

        Assert.Contains("if ($backup.Status -ne 'Succeeded')", phase, StringComparison.Ordinal);
        Assert.Contains("if ($schema.Status -ne 'Succeeded')", phase, StringComparison.Ordinal);
        Assert.Contains("WITH COPY_ONLY, CHECKSUM", db, StringComparison.Ordinal);
        Assert.Contains("RESTORE VERIFYONLY", db, StringComparison.Ordinal);
    }

    [Fact]
    public void DatabaseBackup_RotatesTwoSlotsInsteadOfOneFilePerRelease()
    {
        // One .bak per release filled the shared SQL host's disk; the deploy login cannot delete files there.
        var db = DatabaseScript.Value;
        var backup = db[db.IndexOf("function Invoke-CymBuildDatabaseBackup", StringComparison.Ordinal)..];

        Assert.Contains("Select-CymBuildBackupSlot", backup, StringComparison.Ordinal);
        Assert.Contains("_deploy", db, StringComparison.Ordinal);
        Assert.Contains("_A.bak", db, StringComparison.Ordinal);
        Assert.Contains("_B.bak", db, StringComparison.Ordinal);
        Assert.Contains("msdb.dbo.backupset", db, StringComparison.Ordinal);
        Assert.Contains("ORDER BY bs.backup_finish_date DESC", db, StringComparison.Ordinal);
        Assert.Contains("NAME = @name", backup, StringComparison.Ordinal);
        Assert.DoesNotContain("$Label -replace", backup, StringComparison.Ordinal);
    }

    [Fact]
    public void DatabasePhase_FailuresNeverStopTheApplicationDeployment()
    {
        // Each step catches its own errors and returns a Failed result; the phase runs before the switch.
        var db = DatabaseScript.Value;
        foreach (var step in new[] { "Invoke-CymBuildDatabaseBackup", "Invoke-CymBuildSchemaStep", "Invoke-CymBuildMetadataStep" })
        {
            var body = db[db.IndexOf($"function {step}", StringComparison.Ordinal)..];
            var end = body.IndexOf("\nfunction ", 10, StringComparison.Ordinal);
            body = end > 0 ? body[..end] : body;
            Assert.Contains("} catch {", body, StringComparison.Ordinal);
            Assert.Contains("-Status Failed", body, StringComparison.Ordinal);
        }

        var phaseCall = Script.Value.IndexOf("Invoke-CymBuildDatabasePhase", StringComparison.Ordinal);
        var switchCall = Script.Value.IndexOf("@('Switch')", StringComparison.Ordinal);
        Assert.True(phaseCall >= 0 && switchCall > phaseCall, "The database phase must run before the application switch.");
        Assert.Contains("[switch]$SkipDatabase", Script.Value, StringComparison.Ordinal);
    }

    [Fact]
    public void Script_WrapsApiProcessLookupsForStrictMode()
    {
        // QA 2026-10-13: (Get-ApiProcesses).Count threw on an empty result under StrictMode,
        // after the service had stopped, and the rollback hit the same line.
        var calls = Regex.Matches(Script.Value, @"(?<!function )\bGet-ApiProcesses\b")
            .Select(m => Script.Value.Substring(Math.Max(0, m.Index - 2), 2))
            .ToArray();
        Assert.NotEmpty(calls);
        Assert.All(calls, prefix => Assert.Equal("@(", prefix));
    }

    [Fact]
    public void Script_FailedRestoreStillTriesToStartTheComponent()
    {
        var restoreFailed = Script.Value.IndexOf("RESTORE FAILED", StringComparison.Ordinal);
        var safetyNet = Script.Value.IndexOf("$messages.Add((Start-ComponentIfStopped $c))", StringComparison.Ordinal);
        Assert.True(restoreFailed >= 0 && safetyNet > restoreFailed, "A failed restore must attempt to start the component.");
    }

    [Fact]
    public void Script_ContainsNoCredentials()
    {
        Assert.DoesNotMatch(new Regex(@"(Password|Pwd|User ID|ClientSecret)\s*=", RegexOptions.IgnoreCase), Script.Value);
        Assert.DoesNotMatch(new Regex(@"ConvertTo-SecureString\s+.*-AsPlainText", RegexOptions.IgnoreCase), Script.Value);
    }
}
