using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// AGENTS.md: "Do not run schema or metadata migration from application startup." Scoped to
/// the CymBuild_DB/SCore schema-metadata pipeline entry points (PWA, API, and the metadata CLI
/// tool) - the deployment order these rules protect is idempotent schema -> metadata validation
/// -> idempotent metadata apply -> verification, run explicitly via tools/tooling, never on boot.
/// </summary>
public sealed class StartupMigrationBoundaryTests
{
    private static readonly string[] ForbiddenStartupMigrationTokens =
    [
        ".MigrateAsync(",
        ".Migrate(",
        ".EnsureCreatedAsync(",
        ".EnsureCreated(",
        "EnsureSchemaWorkbenchAsync(",
        "EnsureMetadataWorkbenchAsync(",
        "AcceptApplyPreviewAsync("
    ];

    public static IEnumerable<object[]> ProgramEntryPoints =>
    [
        [@"apps\Concursus.PWA\Program.cs"],
        [@"services\Concursus.API\Program.cs"],
        [@"apps\Concursus.Metadata.Tools\Program.cs"]
    ];

    [Theory]
    [MemberData(nameof(ProgramEntryPoints))]
    public void ProgramEntryPoint_DoesNotInvokeSchemaOrMetadataMigrationAtStartup(string programRelativePath)
    {
        var path = RepositoryLayout.PathFromRoot(programRelativePath.Split('\\'));
        var content = File.ReadAllText(path);

        var violations = ForbiddenStartupMigrationTokens
            .Where(token => content.Contains(token, StringComparison.Ordinal))
            .ToArray();

        Assert.True(
            violations.Length == 0,
            $"{programRelativePath} must not invoke schema/metadata migration at startup. Found:"
            + Environment.NewLine
            + string.Join(Environment.NewLine, violations));
    }
}
