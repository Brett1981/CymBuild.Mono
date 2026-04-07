using Concursus.Common.Shared.Kafka.Config;
using Concursus.Common.Shared.Kafka.Core.Publisher;
using Confluent.Kafka;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Concursus.Common.Shared.Kafka.Core
{
    public static class KafkaServices
    {
        public static IServiceCollection Add(
            IServiceCollection services,
            IConfiguration configuration)
        {
            // Producer MUST be singleton (Kafka producers are intended to be long-lived)
            services.AddSingleton<IProducer<string, string>>(sp =>
            {
                var logger = sp.GetRequiredService<ILoggerFactory>().CreateLogger("KafkaPublisher");
                var kafkaOptions = sp.GetRequiredService<IOptions<KafkaOptions>>().Value;

                return KafkaPublisherConfig.AddKafkaProducer(kafkaOptions, logger);
            });

            // Publisher MUST be singleton too, because it owns a singleton producer.
            // DO NOT register as scoped/transient.
            services.AddSingleton<IKafkaPublisherService, KafkaPublisherService>();

            return services;
        }
    }
}
