using Concursus.Common.Notifications;
using Concursus.Common.Shared.Kafka.Core;
using Concursus.Common.Shared.Kafka.Core.Publisher;
using Concursus.Common.Shared.Notifications.Contracts;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Concursus.Common.Shared.Notifications.Kafka
{
    public sealed class KafkaNotificationPublisher : INotificationPublisher
    {
        private readonly IKafkaPublisherService _kafka;
        private readonly IOptions<KafkaOptions> _opts;
        private readonly ILogger<KafkaNotificationPublisher> _logger;

        public KafkaNotificationPublisher(
            IKafkaPublisherService kafka,
            IOptions<KafkaOptions> opts,
            ILogger<KafkaNotificationPublisher> logger)
        {
            _kafka = kafka;
            _opts = opts;
            _logger = logger;
        }

        public Task PublishAsync(JobClosureDecisionEvent evt, CancellationToken ct = default)
        {
            // If we still want job-closure via Kafka later, keep it here (or leave NoOp for now)
            // For now: publish to the same topic using evt as Data, or a dedicated topic.
            return Task.CompletedTask;
        }

        public async Task PublishAsync(WorkflowStatusNotificationMessage msg, CancellationToken ct = default)
        {
            var topic = _opts.Value.Topic;
            var key = msg.Data.RecordGuid.ToString();

            _logger.LogInformation("Publishing workflow notification. Topic={Topic} Key={Key} Source={Source} Recipients={Count}",
                topic, key, msg.Source, msg.Recipients.Count);

            await _kafka.PublishAsync(topic, key, msg, ct);
        }
    }
}
