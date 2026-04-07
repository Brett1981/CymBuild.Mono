using Concursus.Common.Shared.Notifications.Contracts;
using Microsoft.Extensions.Logging;


namespace Concursus.Common.Notifications;

public interface INotificationPublisher
{
    Task PublishAsync(JobClosureDecisionEvent evt, CancellationToken ct = default);
    // workflow status notifications (auth-needed / send-notification)
    Task PublishAsync(WorkflowStatusNotificationMessage msg, CancellationToken ct = default);
}

/// <summary>
/// Kafka/email out-of-scope. This is a placeholder implementation.
/// In production, a background worker will read SCore.IntegrationOutbox
/// and publish to Kafka, then mark PublishedOnUtc.
/// </summary>
public sealed class NoOpNotificationPublisher : INotificationPublisher
{
    private readonly ILogger<NoOpNotificationPublisher> _logger;

    public NoOpNotificationPublisher(ILogger<NoOpNotificationPublisher> logger) => _logger = logger;

    public Task PublishAsync(JobClosureDecisionEvent evt, CancellationToken ct = default)
    {
        _logger.LogInformation("Notifications disabled/no-op. JobGuid={JobGuid} Decision={Decision}", evt.JobGuid, evt.Decision);
        return Task.CompletedTask;
    }

    public Task PublishAsync(WorkflowStatusNotificationMessage msg, CancellationToken ct = default)
    {
        _logger.LogInformation("Notifications disabled/no-op. Source={Source} Recipients={Count}", msg.Source, msg.Recipients.Count);
        return Task.CompletedTask;
    }
}
