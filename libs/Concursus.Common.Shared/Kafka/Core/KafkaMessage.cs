namespace Concursus.Common.Shared.Kafka.Core
{
    public class KafkaMessage
    {
        public required DateTime TimestampUtc { get; set; } = DateTime.UtcNow;
        public required object Data { get; set; }
    }
}
