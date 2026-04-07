using Concursus.EF.Dto;
using Concursus.EF.Interfaces;
using Confluent.Kafka;
using System.Text.Json;

namespace Concursus.API.Services
{
    public class KafkaOrganisationalUnitSubscriberService : BackgroundService
    {
        private readonly ILogger<KafkaOrganisationalUnitSubscriberService> _logger;
        private readonly IOrganisationalUnitSyncService _ouSyncService;
        private readonly IConsumer<string, string> _consumer;

        public KafkaOrganisationalUnitSubscriberService(ILogger<KafkaOrganisationalUnitSubscriberService> logger,
                                                             IConfiguration config,
                                                             IOrganisationalUnitSyncService ouSyncService)
        {
            _logger = logger;
            _ouSyncService = ouSyncService;
            var consumerConfig = new ConsumerConfig
            {
                BootstrapServers = config["Kafka:BootstrapServers"],
                GroupId = "cymbuild-ou-subscription",
                AutoOffsetReset = AutoOffsetReset.Latest
            };
            _consumer = new ConsumerBuilder<string, string>(consumerConfig).Build();
            _consumer.Subscribe("mdm_organisational_unit_to_cymbuild");
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var result = _consumer.Consume(stoppingToken);
                    var dto = JsonSerializer.Deserialize<OrganisationalUnitKafkaDto>(result.Message.Value);
                    await _ouSyncService.UpdateOrganisationalUnitAsync(dto);
                    _consumer.Commit(result);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing Kafka OU message.");
                }
            }
        }
    }
}