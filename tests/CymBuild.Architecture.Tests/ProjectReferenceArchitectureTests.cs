using Xunit;

namespace CymBuild.Architecture.Tests;

public sealed class ProjectReferenceArchitectureTests
{
    [Fact]
    public void Pwa_DependsOnSharedComponentsWithoutReferencingApiOrEf()
    {
        var references = RepositoryLayout.GetProjectReferences(
            @"apps\Concursus.PWA\Concursus.PWA.csproj");

        Assert.Contains(@"libs\Concursus.Components.Shared\Concursus.Components.Shared.csproj", references);
        Assert.DoesNotContain(@"services\Concursus.API\Concursus.API.csproj", references);
        Assert.DoesNotContain(@"libs\Concursus.EF\Concursus.EF.csproj", references);
    }

    [Fact]
    public void SharedComponents_DependsOnApiClientWithoutReferencingApiOrEf()
    {
        var references = RepositoryLayout.GetProjectReferences(
            @"libs\Concursus.Components.Shared\Concursus.Components.Shared.csproj");

        Assert.Contains(@"libs\Concursus.API.Client\Concursus.API.Client.csproj", references);
        Assert.DoesNotContain(@"services\Concursus.API\Concursus.API.csproj", references);
        Assert.DoesNotContain(@"libs\Concursus.EF\Concursus.EF.csproj", references);
    }

    [Fact]
    public void ApiClient_DependsOnCommonSharedWithoutReferencingServerLayers()
    {
        var references = RepositoryLayout.GetProjectReferences(
            @"libs\Concursus.API.Client\Concursus.API.Client.csproj");

        Assert.Equal(new[] { @"libs\Concursus.Common.Shared\Concursus.Common.Shared.csproj" }, references);
    }

    [Fact]
    public void Api_DependsOnEfAndCommonSharedWithoutReferencingUi()
    {
        var references = RepositoryLayout.GetProjectReferences(
            @"services\Concursus.API\Concursus.API.csproj");

        Assert.Contains(@"libs\Concursus.Common.Shared\Concursus.Common.Shared.csproj", references);
        Assert.Contains(@"libs\Concursus.EF\Concursus.EF.csproj", references);
        Assert.DoesNotContain(@"apps\Concursus.PWA\Concursus.PWA.csproj", references);
        Assert.DoesNotContain(@"libs\Concursus.Components.Shared\Concursus.Components.Shared.csproj", references);
    }

    [Fact]
    public void Ef_DependsOnlyOnCommonShared()
    {
        var references = RepositoryLayout.GetProjectReferences(
            @"libs\Concursus.EF\Concursus.EF.csproj");

        Assert.Equal(new[] { @"libs\Concursus.Common.Shared\Concursus.Common.Shared.csproj" }, references);
    }

    [Fact]
    public void CommonShared_HasNoProjectReferences()
    {
        var references = RepositoryLayout.GetProjectReferences(
            @"libs\Concursus.Common.Shared\Concursus.Common.Shared.csproj");

        Assert.Empty(references);
    }
}
