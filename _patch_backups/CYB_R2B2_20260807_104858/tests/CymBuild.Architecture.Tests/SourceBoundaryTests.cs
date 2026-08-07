using Xunit;

namespace CymBuild.Architecture.Tests;

public sealed class SourceBoundaryTests
{
    private static readonly string[] ForbiddenPwaPersistenceTokens =
    [
        "using Concursus.EF",
        "using Microsoft.Data.SqlClient",
        "new SqlConnection(",
        "DbContextOptions<",
        "Microsoft.EntityFrameworkCore"
    ];

    [Fact]
    public void PwaSource_DoesNotContainDirectEfOrSqlPersistenceCode()
    {
        var violations = new List<string>();

        foreach (var file in RepositoryLayout.EnumerateSourceFiles(@"apps\Concursus.PWA"))
        {
            var content = File.ReadAllText(file);
            foreach (var token in ForbiddenPwaPersistenceTokens)
            {
                if (content.Contains(token, StringComparison.Ordinal))
                {
                    violations.Add($"{Path.GetRelativePath(RepositoryLayout.Root, file)} contains '{token}'.");
                }
            }
        }

        Assert.True(
            violations.Count == 0,
            "PWA persistence-boundary violations were found:" + Environment.NewLine + string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void FormHelper_RemainsInApiClientLayer()
    {
        var expected = RepositoryLayout.PathFromRoot("libs", "Concursus.API.Client", "FormHelper.cs");
        Assert.True(File.Exists(expected), $"Expected FormHelper gateway was not found at '{expected}'.");

        var misplaced = RepositoryLayout
            .EnumerateSourceFiles(@"apps\Concursus.PWA")
            .Where(path => Path.GetFileName(path).StartsWith("FormHelper", StringComparison.OrdinalIgnoreCase))
            .ToArray();

        Assert.Empty(misplaced);
    }
}
