using Xunit;

namespace CymBuild.Architecture.Tests;

public sealed class TestInfrastructureTests
{
    [Fact]
    public void EveryFastTestProject_IsIncludedInRootSolution()
    {
        var solutionText = File.ReadAllText(
            RepositoryLayout.PathFromRoot("CymBuild.Monorepo.sln"));

        var missing = RepositoryLayout
            .GetFastTestProjectPaths()
            .Where(path => !solutionText.Contains($"\"{path}\"", StringComparison.OrdinalIgnoreCase))
            .ToArray();

        Assert.True(
            missing.Length == 0,
            "Fast test projects missing from CymBuild.Monorepo.sln:" + Environment.NewLine + string.Join(Environment.NewLine, missing));
    }

    [Fact]
    public void EveryFastTestProject_ImportsSharedTestingProps()
    {
        var missingImport = RepositoryLayout
            .GetFastTestProjectPaths()
            .Where(path =>
            {
                var fullPath = RepositoryLayout.PathFromRoot(path.Split('\\'));
                var content = File.ReadAllText(fullPath);
                return !content.Contains(
                    @"$(RepoRoot)tests\CymBuild.Testing.props",
                    StringComparison.OrdinalIgnoreCase);
            })
            .ToArray();

        Assert.True(
            missingImport.Length == 0,
            "Fast test projects not importing tests\\CymBuild.Testing.props:" + Environment.NewLine
            + string.Join(Environment.NewLine, missingImport));
    }
}
