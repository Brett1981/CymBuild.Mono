namespace Concursus.Common.Shared.Kafka.Core
{
    public class KafkaOptions
    {
        public string BootstrapServers { get; set; } = null!;
        public string Topic { get; set; } = null!;
        public string SaslUsername { get; set; } = null!;
        public string SaslPassword { get; set; } = null!;
        public ProducerOptions Producer { get; set; } = new();
    }

    public class ProducerOptions
    {
        public int Retries { get; set; }
        public int LingerMs { get; set; }
        public int MessageSendMaxRetries { get; set; }
        public bool EnableIdempotence { get; set; }
        public int BatchSize { get; set; }
        public int RetryBackoffMs { get; set; }
        public int MaxInFlight { get; set; }
    }
}
