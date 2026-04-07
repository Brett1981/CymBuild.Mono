namespace Concursus.Common.Shared.Kafka.Core.Publisher
{
    /// <summary>
    /// Interface for publishing events to Kafka topics
    /// </summary>
    public interface IKafkaPublisherService
    {
        /// <summary>
        /// Publishes an event to a Kafka topic with a Guid key
        /// </summary>
        /// <typeparam name="TEvent">The type of event to publish</typeparam>
        /// <param name="topic">The Kafka topic name</param>
        /// <param name="key">The message key (typically an ID or Guid)</param>
        /// <param name="eventData">The event data to publish</param>
        /// <param name="cancellationToken">Cancellation token</param>
        Task PublishAsync<TEvent>(string topic, string key, TEvent eventData, CancellationToken cancellationToken = default) 
            where TEvent : class;
    }
}
