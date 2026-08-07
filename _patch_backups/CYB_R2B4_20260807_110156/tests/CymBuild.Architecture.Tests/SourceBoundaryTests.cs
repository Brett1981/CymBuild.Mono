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
    [Fact]
    public void PwaAndApiClient_DoNotReferenceRetiredSage200MicroserviceClient()
    {
        const string retiredSageNamespace = "Sage200Microservice";
        var violations = new List<string>();

        foreach (var projectDirectory in new[] { @"apps\Concursus.PWA", @"libs\Concursus.API.Client" })
        {
            foreach (var file in RepositoryLayout.EnumerateSourceFiles(projectDirectory))
            {
                var content = File.ReadAllText(file);
                if (content.Contains(retiredSageNamespace, StringComparison.Ordinal))
                {
                    violations.Add($"{Path.GetRelativePath(RepositoryLayout.Root, file)} references '{retiredSageNamespace}'.");
                }
            }
        }

        var apiClientProject = RepositoryLayout.PathFromRoot(
            "libs", "Concursus.API.Client", "Concursus.API.Client.csproj");
        var apiClientProjectContent = File.ReadAllText(apiClientProject);
        if (apiClientProjectContent.Contains(retiredSageNamespace, StringComparison.Ordinal))
        {
            violations.Add("libs\\Concursus.API.Client\\Concursus.API.Client.csproj references the retired Sage200Microservice.");
        }

        Assert.True(
            violations.Count == 0,
            "Retired Sage200Microservice client references were found in the PWA/API.Client boundary:"
            + Environment.NewLine
            + string.Join(Environment.NewLine, violations));
    }

}
