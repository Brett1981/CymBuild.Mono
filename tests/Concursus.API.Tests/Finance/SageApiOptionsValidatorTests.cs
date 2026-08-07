using Concursus.API.Sage.SOAP;
using Microsoft.Extensions.Hosting;
using Moq;
using Xunit;

namespace Concursus.API.Tests.Finance;

public sealed class SageApiOptionsValidatorTests
{
    [Fact]
    public void Validate_DisabledIntegrationSucceedsWithoutBaseUrl()
    {
        var result = CreateValidator(Environments.Production).Validate(null, new SageApiOptions { Enabled = false });

        Assert.True(result.Succeeded);
    }

    [Fact]
    public void Validate_EnabledIntegrationRequiresBaseUrl()
    {
        var result = CreateValidator(Environments.Development).Validate(null, new SageApiOptions { Enabled = true });

        Assert.False(result.Succeeded);
        Assert.Contains("BaseUrl", Assert.Single(result.Failures));
    }

    [Theory]
    [InlineData("not a uri")]
    [InlineData("ftp://sage.example.test")]
    public void Validate_RejectsInvalidOrUnsupportedBaseUrl(string baseUrl)
    {
        var result = CreateValidator(Environments.Development).Validate(null, CreateEnabledOptions(baseUrl));

        Assert.False(result.Succeeded);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(301)]
    public void Validate_RejectsTimeoutOutsideSupportedRange(int timeoutSeconds)
    {
        var options = CreateEnabledOptions("https://sage.example.test");
        options.TimeoutSeconds = timeoutSeconds;

        var result = CreateValidator(Environments.Production).Validate(null, options);

        Assert.False(result.Succeeded);
        Assert.Contains("TimeoutSeconds", Assert.Single(result.Failures));
    }

    [Fact]
    public void Validate_RequireApiKeyRejectsMissingKey()
    {
        var options = CreateEnabledOptions("https://sage.example.test");
        options.RequireApiKey = true;
        options.ApiKey = " ";

        var result = CreateValidator(Environments.Production).Validate(null, options);

        Assert.False(result.Succeeded);
        Assert.Contains("ApiKey", Assert.Single(result.Failures));
    }

    [Fact]
    public void Validate_RejectsEmptyApiKeyHeaderName()
    {
        var options = CreateEnabledOptions("https://sage.example.test");
        options.ApiKeyHeaderName = " ";

        var result = CreateValidator(Environments.Production).Validate(null, options);

        Assert.False(result.Succeeded);
        Assert.Contains("ApiKeyHeaderName", Assert.Single(result.Failures));
    }

    [Fact]
    public void Validate_HttpRequiresExplicitDevelopmentAllowance()
    {
        var options = CreateEnabledOptions("http://localhost:8080");
        options.AllowInsecureHttp = false;

        var result = CreateValidator(Environments.Development).Validate(null, options);

        Assert.False(result.Succeeded);
        Assert.Contains("AllowInsecureHttp", Assert.Single(result.Failures));
    }

    [Fact]
    public void Validate_NonDevelopmentRejectsLocalhost()
    {
        var options = CreateEnabledOptions("http://localhost:8080");
        options.AllowInsecureHttp = true;

        var result = CreateValidator(Environments.Production).Validate(null, options);

        Assert.False(result.Succeeded);
        Assert.True(Assert.Single(result.Failures).Contains("localhost", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Validate_NonDevelopmentRequiresHttps()
    {
        var options = CreateEnabledOptions("http://sage.example.test");
        options.AllowInsecureHttp = true;

        var result = CreateValidator(Environments.Production).Validate(null, options);

        Assert.False(result.Succeeded);
        Assert.True(Assert.Single(result.Failures).Contains("HTTPS", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Validate_DevelopmentAllowsExplicitLocalHttp()
    {
        var options = CreateEnabledOptions("http://localhost:8080");
        options.AllowInsecureHttp = true;

        var result = CreateValidator(Environments.Development).Validate(null, options);

        Assert.True(result.Succeeded);
    }

    [Fact]
    public void Validate_ProductionAllowsValidHttpsConfiguration()
    {
        var options = CreateEnabledOptions("https://sage.example.test");
        options.RequireApiKey = true;
        options.ApiKey = "secret";

        var result = CreateValidator(Environments.Production).Validate(null, options);

        Assert.True(result.Succeeded);
    }

    private static SageApiOptionsValidator CreateValidator(string environmentName)
    {
        var environment = new Mock<IHostEnvironment>();
        environment.SetupGet(x => x.EnvironmentName).Returns(environmentName);
        return new SageApiOptionsValidator(environment.Object);
    }

    private static SageApiOptions CreateEnabledOptions(string baseUrl)
    {
        return new SageApiOptions
        {
            Enabled = true,
            BaseUrl = baseUrl,
            TimeoutSeconds = 60,
            ApiKeyHeaderName = "Authorization"
        };
    }
}
