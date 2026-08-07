using Concursus.API.Services;
using Concursus.API.Services.Finance;
using Concursus.API.Services.InvoiceAutomation;
using Concursus.API.Services.Outbox;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace Concursus.API.Runtime;

public static class CymBuildRuntimeServiceCollectionExtensions
{
    /// <summary>
    /// Registers the hosted workers selected by the CymBuild runtime role.
    /// With no CymBuildRuntime configuration, all five workers are registered
    /// in their existing startup order so current behaviour is preserved.
    /// </summary>
    public static IServiceCollection AddCymBuildRuntime(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);

        services.AddSingleton<IValidateOptions<CymBuildRuntimeOptions>, CymBuildRuntimeOptionsValidator>();
        services
            .AddOptions<CymBuildRuntimeOptions>()
            .Bind(configuration.GetSection(CymBuildRuntimeOptions.SectionName))
            .ValidateOnStart();

        var selected = new CymBuildRuntimeOptions();
        configuration.GetSection(CymBuildRuntimeOptions.SectionName).Bind(selected);
        ValidateSelection(selected);

        RegisterSelectedHostedServices(services, selected);
        return services;
    }

    private static void RegisterSelectedHostedServices(
        IServiceCollection services,
        CymBuildRuntimeOptions options)
    {
        switch (options.Mode)
        {
            case CymBuildRuntimeMode.Combined:
                // Preserve the original Program.cs registration/startup order.
                services.AddHostedService<SageInboundPaymentSyncWorker>();
                services.AddHostedService<WorkflowOutboxKafkaPublisherWorker>();
                services.AddHostedService<InvoiceAutomationScheduledWorker>();
                services.AddHostedService<SharePointStructureRepairWorker>();
                services.AddHostedService<SageTransactionSubmissionWorker>();
                return;

            case CymBuildRuntimeMode.ApiOnly:
                return;

            case CymBuildRuntimeMode.Worker:
                RegisterSingleWorker(services, options.WorkerRole);
                return;

            default:
                throw new InvalidOperationException(
                    $"Unsupported CymBuild runtime mode '{options.Mode}'.");
        }
    }

    private static void RegisterSingleWorker(
        IServiceCollection services,
        CymBuildWorkerRole workerRole)
    {
        switch (workerRole)
        {
            case CymBuildWorkerRole.InvoiceAutomation:
                services.AddHostedService<InvoiceAutomationScheduledWorker>();
                return;

            case CymBuildWorkerRole.WorkflowOutbox:
                services.AddHostedService<WorkflowOutboxKafkaPublisherWorker>();
                return;

            case CymBuildWorkerRole.SharePointRepair:
                services.AddHostedService<SharePointStructureRepairWorker>();
                return;

            case CymBuildWorkerRole.SageSubmission:
                services.AddHostedService<SageTransactionSubmissionWorker>();
                return;

            case CymBuildWorkerRole.SageInbound:
                services.AddHostedService<SageInboundPaymentSyncWorker>();
                return;

            case CymBuildWorkerRole.None:
            default:
                throw new InvalidOperationException(
                    $"Unsupported CymBuild worker role '{workerRole}'.");
        }
    }

    private static void ValidateSelection(CymBuildRuntimeOptions options)
    {
        var failures = CymBuildRuntimeOptionsValidator.ValidateCore(options);
        if (failures.Count == 0)
        {
            return;
        }

        throw new OptionsValidationException(
            Options.DefaultName,
            typeof(CymBuildRuntimeOptions),
            failures);
    }
}
