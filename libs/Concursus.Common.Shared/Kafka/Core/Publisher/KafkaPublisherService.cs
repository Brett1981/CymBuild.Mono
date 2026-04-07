using Confluent.Kafka;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace Concursus.Common.Shared.Kafka.Core.Publisher
{
    /// <summary>
    /// Service for publishing events to Kafka topics
    /// </summary>
    public class KafkaPublisherService : IKafkaPublisherService, IDisposable
    {
        private readonly ILogger<KafkaPublisherService> _logger;

        // IMPORTANT: This should typically be a long-lived producer (singleton)
        // We keep it readonly but make disposal safe.
        private readonly IProducer<string, string> _producer;

        private bool _disposed;

        public KafkaPublisherService(
            ILogger<KafkaPublisherService> logger,
            IProducer<string, string> producer)
        {
            _logger = logger;
            _producer = producer;
        }

        /// <summary>
        /// Publishes an event to a Kafka topic
        /// </summary>
        public async Task PublishAsync<TEvent>(
            string topic,
            string key,
            TEvent eventData,
            CancellationToken cancellationToken = default)
            where TEvent : class
        {
            if (_disposed)
                throw new ObjectDisposedException(nameof(KafkaPublisherService));

            if (string.IsNullOrWhiteSpace(topic))
                throw new ArgumentNullException(nameof(topic));

            if (string.IsNullOrWhiteSpace(key))
                throw new ArgumentNullException(nameof(key));

            if (eventData is null)
                throw new ArgumentNullException(nameof(eventData));

            try
            {
                var serializedEvent = JsonSerializer.Serialize(eventData, new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                    WriteIndented = false
                });

                var message = new Message<string, string>
                {
                    Key = key,
                    Value = serializedEvent,
                    Timestamp = new Timestamp(DateTime.UtcNow)
                };

                _logger.LogDebug(
                    "Publishing event to Kafka. Topic: {Topic}, Key: {Key}, EventData: {EventData}",
                    topic, key, serializedEvent);

                var deliveryResult = await _producer.ProduceAsync(topic, message, cancellationToken);

                _logger.LogInformation(
                    "Published event to Kafka. Topic: {Topic}, Key: {Key}, Partition: {Partition}, Offset: {Offset}",
                    topic, key, deliveryResult.Partition.Value, deliveryResult.Offset.Value);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                // Normal during shutdown / service stop. Bubble so caller can exit cleanly.
                throw;
            }
            catch (ProduceException<string, string> ex)
            {
                _logger.LogError(ex,
                    "Failed to publish event to Kafka. Topic: {Topic}, Key: {Key}, Error: {Error}",
                    topic, key, ex.Error.Reason);
                throw;
            }
            catch (ObjectDisposedException ex)
            {
                // This can happen during shutdown if the producer is disposed while worker is stopping.
                _logger.LogWarning(ex,
                    "Kafka producer disposed during publish. Topic: {Topic}, Key: {Key}",
                    topic, key);
                throw;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex,
                    "Unexpected error publishing event to Kafka. Topic: {Topic}, Key: {Key}",
                    topic, key);
                throw;
            }
        }

        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        /// <summary>
        /// IMPORTANT: Dispose must never throw.
        /// In Windows Service / hosted scenarios, shutdown ordering can mean Kafka handle is already closed.
        /// </summary>
        protected virtual void Dispose(bool disposing)
        {
            if (_disposed) return;
            _disposed = true;

            if (!disposing) return;

            try
            {
                // Best-effort flush only. During shutdown, Kafka handle may already be destroyed.
                _producer?.Flush(TimeSpan.FromSeconds(5));
            }
            catch (ObjectDisposedException)
            {
                // Handle already closed/destroyed. Safe to ignore.
            }
            catch (KafkaException)
            {
                // Best-effort on shutdown.
            }
            catch
            {
                // Never throw from Dispose.
            }

            try
            {
                _producer?.Dispose();
            }
            catch
            {
                // Never throw from Dispose.
            }
        }
    }
}
