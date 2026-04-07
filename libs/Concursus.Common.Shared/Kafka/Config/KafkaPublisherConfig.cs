using Concursus.Common.Shared.Kafka.Core;
using Confluent.Kafka;
using Microsoft.Extensions.Logging;

namespace Concursus.Common.Shared.Kafka.Config
{
    public static class KafkaPublisherConfig
    {
        public static IProducer<string, string> AddKafkaProducer(
            KafkaOptions options, ILogger logger)
        {
            var config = new ProducerConfig
            {
                BootstrapServers = options.BootstrapServers,
                Acks = Acks.All, // Wait for all in-sync replicas to acknowledge
                EnableIdempotence = options.Producer.EnableIdempotence, // Prevent duplicate messages
                MaxInFlight = options.Producer.MaxInFlight,
                MessageSendMaxRetries = options.Producer.MessageSendMaxRetries,
                RetryBackoffMs = options.Producer.RetryBackoffMs,
                // Compression for better performance
                CompressionType = CompressionType.Snappy,
                // Batching for efficiency
                LingerMs = options.Producer.LingerMs,
                BatchSize = options.Producer.BatchSize,

                SecurityProtocol = SecurityProtocol.SaslPlaintext,
                SaslMechanism = SaslMechanism.ScramSha512,
                SaslUsername = options.SaslUsername,
                SaslPassword = options.SaslPassword

            };

            return new ProducerBuilder<string, string>(config)
                .SetErrorHandler((_, e) =>
                {
                    logger.LogError("Kafka producer error: {Reason}", e.Reason);
                })
                .SetLogHandler((_, logMessage) =>
                {
                    var logLevel = logMessage.Level switch
                    {
                        SyslogLevel.Emergency or SyslogLevel.Alert or SyslogLevel.Critical or SyslogLevel.Error => LogLevel.Error,
                        SyslogLevel.Warning => LogLevel.Warning,
                        SyslogLevel.Notice or SyslogLevel.Info => LogLevel.Information,
                        _ => LogLevel.Debug
                    };
                    logger.Log(logLevel, "Kafka producer log: {Message}", logMessage.Message);
                })
                .Build();
        }
    }
}