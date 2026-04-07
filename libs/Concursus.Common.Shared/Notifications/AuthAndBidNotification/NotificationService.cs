using Concursus.Common.Shared.Helpers;
using Concursus.Common.Shared.Kafka.Core;
using Concursus.Common.Shared.Kafka.Core.Publisher;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Concursus.Common.Shared.Notifications.AuthAndBidNotification
{
    /// <summary>
    /// Example service showing how to use generic Kafka publisher when data is updated
    /// Demonstrates publishing to different topics dynamically
    /// </summary>
    public class NotificationService
    {
        private readonly IKafkaPublisherService _kafkaPublisher;
        private readonly IOptions<KafkaOptions> _options;
        private readonly ILogger<NotificationService> _logger;
        private string TOPIC;

        public NotificationService(
            IKafkaPublisherService kafkaPublisher,
            IOptions<KafkaOptions> options,
            ILogger<NotificationService> logger)
        {
            _kafkaPublisher = kafkaPublisher;
            _options = options;
            _logger = logger;
            TOPIC = _options.Value.Topic;
        }

        /// <summary>
        /// Example: Dynamic source routing based on notification type
        /// </summary>
        public async Task PublishNotificationAsync(string userGroupCode, AuthAndBidMessage jobData)
        {
            try
            {
                string key = Guid.NewGuid().ToString();

                _logger.LogInformation(
                   "Publishing event to topic {Topic}. Key: {Key}",
                   TOPIC, key);

                var dataFromFile = FileHelper.GetDataFromFile(userGroupCode, "./AuthAndBidNotificationContacts.json");

                JObject authObj = JObject.Parse(dataFromFile);

                // Get "source" as JSON string
                string sourceJson = authObj["source"]?.ToString();
                jobData.Source = JsonConvert.DeserializeObject<string>(sourceJson);

                // Get "recipients" as JSON string
                string recipientsJson = authObj["recipients"]?.ToString();
                jobData.Recipients = JsonConvert.DeserializeObject<List<string>>(recipientsJson);

                await _kafkaPublisher.PublishAsync(TOPIC, key, jobData);

                _logger.LogInformation(
                   "Successfully published event to topic {Topic}. Key: {Key}, Source: {Source}",
                   TOPIC, key, jobData.Source);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to publish routed notification event.{userGroupCode}", userGroupCode);
                throw;
            }
        }
    }
}
