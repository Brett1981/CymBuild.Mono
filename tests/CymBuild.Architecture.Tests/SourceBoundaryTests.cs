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
    public void PwaApiClientAndSharedComponents_DoNotReferenceRetiredSage200MicroserviceClient()
    {
        const string retiredSageNamespace = "Sage200Microservice";
        var violations = new List<string>();

        foreach (var projectDirectory in new[]
        {
            @"apps\Concursus.PWA",
            @"libs\Concursus.API.Client",
            @"libs\Concursus.Components.Shared"
        })
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
            "Retired Sage200Microservice client references were found in the PWA/API.Client/shared-components boundary:"
            + Environment.NewLine
            + string.Join(Environment.NewLine, violations));
    }


    [Fact]
    public void PostcodeLookupTab_UsesFormHelperInsteadOfDirectBusinessHttp()
    {
        var componentPath = RepositoryLayout.PathFromRoot(
            "apps", "Concursus.PWA", "Shared", "PostcodeLookupTab.razor");
        var content = File.ReadAllText(componentPath);

        var forbiddenTokens = new[]
        {
            "IHttpClientFactory",
            "HttpFactory.CreateClient(",
            "PostAsJsonAsync(",
            "CreateClient(\"PostcodeLookupUI\")",
            "CreateClient(\"AddressLookupUI\")",
            "http://localhost:5041",
            "api/Postcode/lookup",
            "api/Address/lookup"
        };

        var violations = forbiddenTokens
            .Where(token => content.Contains(token, StringComparison.Ordinal))
            .ToArray();

        Assert.True(
            violations.Length == 0,
            "PostcodeLookupTab contains direct lookup-service HTTP coupling:"
            + Environment.NewLine
            + string.Join(Environment.NewLine, violations));

        Assert.Contains("AddressLookupSearchAsync(", content, StringComparison.Ordinal);
        Assert.Contains("AddressLookupResolveAsync(", content, StringComparison.Ordinal);
    }

    [Fact]
    public void DynamicGridView_UsesFormHelperForMonthlySeriesInsteadOfDirectBusinessHttp()
    {
        var razorPath = RepositoryLayout.PathFromRoot(
            "apps", "Concursus.PWA", "Shared", "DynamicGridView.razor");
        var codeBehindPath = RepositoryLayout.PathFromRoot(
            "apps", "Concursus.PWA", "Shared", "DynamicGridView.razor.cs");
        var programPath = RepositoryLayout.PathFromRoot(
            "apps", "Concursus.PWA", "Program.cs");
        var formHelperPath = RepositoryLayout.PathFromRoot(
            "libs", "Concursus.API.Client", "FormHelper.cs");
        var protoPath = RepositoryLayout.PathFromRoot(
            "services", "Concursus.API", "Protos", "core.proto");
        var coreServicePath = RepositoryLayout.PathFromRoot(
            "services", "Concursus.API", "Services", "CoreService.cs");
        var efCorePath = RepositoryLayout.PathFromRoot(
            "libs", "Concursus.EF", "Core.cs");
        var controllerPath = RepositoryLayout.PathFromRoot(
            "services", "Concursus.API", "Controllers", "InvoiceSchedulesController.cs");

        var razor = File.ReadAllText(razorPath);
        var codeBehind = File.ReadAllText(codeBehindPath);
        var program = File.ReadAllText(programPath);
        var formHelper = File.ReadAllText(formHelperPath);
        var proto = File.ReadAllText(protoPath);
        var coreService = File.ReadAllText(coreServicePath);
        var efCore = File.ReadAllText(efCorePath);
        var controller = File.ReadAllText(controllerPath);

        var directHttpTokens = new[]
        {
            "IHttpClientFactory",
            "HttpClientFactory.CreateClient(",
            "CreateClient(\"ShoreApiHttp\")",
            "PostAsJsonAsync(",
            "api/invoice-schedules/",
            "month-configurations/generate"
        };

        var violations = directHttpTokens
            .Where(token =>
                razor.Contains(token, StringComparison.Ordinal) ||
                codeBehind.Contains(token, StringComparison.Ordinal))
            .ToArray();

        Assert.True(
            violations.Length == 0,
            "DynamicGridView contains direct invoice-schedule business HTTP coupling:"
            + Environment.NewLine
            + string.Join(Environment.NewLine, violations));

        Assert.False(
            program.Contains("AddHttpClient(\"ShoreApiHttp\"", StringComparison.Ordinal),
            "The obsolete ShoreApiHttp PWA client registration must not be present.");

        Assert.True(
            codeBehind.Contains("InvoiceScheduleMonthlySeriesGenerateAsync(", StringComparison.Ordinal),
            "DynamicGridView must call FormHelper for monthly-series generation.");
        Assert.True(
            formHelper.Contains("_coreClient.InvoiceScheduleMonthlySeriesGenerateAsync(", StringComparison.Ordinal),
            "FormHelper must call the Concursus Core gRPC method.");
        Assert.True(
            proto.Contains("rpc InvoiceScheduleMonthlySeriesGenerate", StringComparison.Ordinal),
            "The Core gRPC monthly-series contract must exist.");
        Assert.True(
            coreService.Contains(".InvoiceScheduleMonthlySeriesGenerateAsync(", StringComparison.Ordinal),
            "CoreService must call the EF monthly-series method.");
        Assert.True(
            efCore.Contains("[SFin].[InvoiceScheduleMonthConfiguration_GenerateMonthlySeries]", StringComparison.Ordinal),
            "EF must execute the existing source-controlled monthly-series stored procedure.");

        Assert.True(
            controller.Contains(
                "[HttpPost(\"{invoiceScheduleGuid:guid}/month-configurations/generate\")]",
                StringComparison.Ordinal),
            "The existing REST endpoint must remain for backward-compatible/non-PWA callers.");
    }
}
