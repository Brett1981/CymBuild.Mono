using Xunit;

namespace CymBuild.Architecture.Tests;

// 2026-09-24, QA run b524d925: DEV held duplicate system-named UNIQUE constraints on Guid, so the
// compare's one-to-one structural pairing skipped them and they were deployed as MissingInTarget.
// The runner can only recreate a system-named key constraint under an explicit copy of DEV's
// generated name (is_system_named = 0), so post-deployment verification can never pass. Validation
// must fail such rows, and the runner must refuse them independently of validation.
public sealed class SchemaSystemNamedKeyConstraintSourceContractTests
{
    [Fact]
    public void Validation_FailsSystemNamedKeyConstraintRowsWithExplicitNameGuidance()
    {
        var service = NormaliseNewLines(File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["libs", "Concursus.EF", "SchemaMigration", "SchemaMigrationRules.cs"])));

        Assert.Contains("private static bool IsSystemNamedKeyConstraintDefinition(string? definition) =>", service, StringComparison.Ordinal);
        Assert.Contains("&& (IsSystemNamedKeyConstraintDefinition(row.SourceDefinition)\n                    || IsSystemNamedKeyConstraintDefinition(row.TargetDefinition));", service, StringComparison.Ordinal);
        Assert.Contains("_ when isSystemNamedKeyConstraintChange => \"Fail\",", service, StringComparison.Ordinal);
        Assert.Contains("_ when isSystemNamedKeyConstraintChange => \"SYSTEM_NAMED_CONSTRAINT_REQUIRES_EXPLICIT_NAME\",", service, StringComparison.Ordinal);
        Assert.Contains("Give it an explicit name in source first", service, StringComparison.Ordinal);
    }

    [Fact]
    public void Runner_RefusesSystemNamedKeyConstraintsBeforeMaterialization()
    {
        var runner = NormaliseNewLines(File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1"])));

        Assert.Contains("function Test-CymBuildSystemNamedKeyConstraintDefinition {", runner, StringComparison.Ordinal);

        var constraintBranch = runner.IndexOf(
            "    if ($objectType.Equals(\"Constraint\", [System.StringComparison]::OrdinalIgnoreCase)) {\n        # A system-named key constraint",
            StringComparison.Ordinal);
        Assert.True(constraintBranch >= 0, "Resolve-DeploymentItem constraint branch must start with the system-named guard.");

        var guard = runner.IndexOf("(Test-CymBuildSystemNamedKeyConstraintDefinition -Definition $targetDefinition)", constraintBranch, StringComparison.Ordinal);
        var materialize = runner.IndexOf("New-MaterializedConstraintSourceFiles -Row $Row", constraintBranch, StringComparison.Ordinal);
        Assert.True(guard > constraintBranch && guard < materialize, "The guard must run before constraint materialization.");
    }

    private static string NormaliseNewLines(string text) => text.Replace("\r\n", "\n", StringComparison.Ordinal);
}
