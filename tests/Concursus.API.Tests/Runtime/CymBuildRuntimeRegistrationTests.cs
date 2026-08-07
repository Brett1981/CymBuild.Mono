using Concursus.API.Runtime;
using Concursus.API.Services;
using Concursus.API.Services.Finance;
using Concursus.API.Services.InvoiceAutomation;
using Concursus.API.Services.Outbox;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Xunit;

namespace Concursus.API.Tests.Runtime;

public sealed class CymBuildRuntimeRegistrationTests
{
    private static readonly Type[] CombinedWorkerTypes =
    [
        typeof(SageInboundPaymentSyncWorker),
        typeof(WorkflowOutboxKafkaPublisherWorker),
        typeof(InvoiceAutomationScheduledWorker),
        typeof(SharePointStructureRepairWorker),
        typeof(SageTransactionSubmissionWorker)
    ];

    [Fact]
    public void DefaultConfiguration_PreservesCombinedWorkerRegistrationAndOrder()
    {
        var services = CreateServices();

        services.AddCymBuildRuntime(BuildConfiguration());

        Assert.Equal(CombinedWorkerTypes, GetHostedWorkerTypes(services));
    }

    [Fact]
    public void ApiOnly_RegistersNoCymBuildHostedWorkers()
    {
        var services = CreateServices();

        services.AddCymBuildRuntime(BuildConfiguration(
            ("CymBuildRuntime:Mode", "ApiOnly")));

        Assert.Empty(GetHostedWorkerTypes(services));
    }

    [Theory]
    [InlineData("InvoiceAutomation", typeof(InvoiceAutomationScheduledWorker))]
    [InlineData("WorkflowOutbox", typeof(WorkflowOutboxKafkaPublisherWorker))]
    [InlineData("SharePointRepair", typeof(SharePointStructureRepairWorker))]
    [InlineData("SageSubmission", typeof(SageTransactionSubmissionWorker))]
    [InlineData("SageInbound", typeof(SageInboundPaymentSyncWorker))]
    public void WorkerMode_RegistersExactlyOneSelectedWorker(
        string workerRole,
        Type expectedWorkerType)
    {
        var services = CreateServices();

        services.AddCymBuildRuntime(BuildConfiguration(
            ("CymBuildRuntime:Mode", "Worker"),
            ("CymBuildRuntime:WorkerRole", workerRole)));

        Assert.Equal([expectedWorkerType], GetHostedWorkerTypes(services));
    }

    [Theory]
    [InlineData("Worker", "None")]
    [InlineData("ApiOnly", "InvoiceAutomation")]
    [InlineData("Combined", "WorkflowOutbox")]
    public void InvalidModeAndRoleCombination_IsRejectedAtRegistration(
        string mode,
        string workerRole)
    {
        var services = CreateServices();

        var exception = Assert.Throws<OptionsValidationException>(() =>
            services.AddCymBuildRuntime(BuildConfiguration(
                ("CymBuildRuntime:Mode", mode),
                ("CymBuildRuntime:WorkerRole", workerRole))));

        Assert.Contains("CymBuildRuntime", exception.Message);
    }

    [Fact]
    public void OptionsDefaults_PreserveExistingCombinedBehaviour()
    {
        var options = new CymBuildRuntimeOptions();

        Assert.Equal(CymBuildRuntimeMode.Combined, options.Mode);
        Assert.Equal(CymBuildWorkerRole.None, options.WorkerRole);
        Assert.True(new CymBuildRuntimeOptionsValidator().Validate(null, options).Succeeded);
    }

    private static ServiceCollection CreateServices() => new();

    private static IConfiguration BuildConfiguration(
        params (string Key, string Value)[] entries)
    {
        var values = entries.ToDictionary(
            entry => entry.Key,
            entry => (string?)entry.Value,
            StringComparer.OrdinalIgnoreCase);

        return new ConfigurationBuilder()
            .AddInMemoryCollection(values)
            .Build();
    }

    private static Type[] GetHostedWorkerTypes(IServiceCollection services)
    {
        return services
            .Where(descriptor => descriptor.ServiceType == typeof(IHostedService))
            .Select(descriptor => descriptor.ImplementationType)
            .Where(type => type is not null)
            .Cast<Type>()
            .ToArray();
    }
}
