using Concursus.Common.Shared.Kafka.Core;

namespace Concursus.Common.Shared.Notifications.AuthAndBidNotification
{
    public class AuthAndBidMessage : KafkaMessage
    {
        public required string Source { get; set; }
        public List<string> Recipients { get; set; } = [];
        public List<Links> Links { get; set; } = [];
    }

    public class Links
    {
        public string? Key { get; set; }
        public string? Value { get; set; }
    }
}
