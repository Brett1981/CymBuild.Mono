using Concursus.EF.Dto;
using Concursus.EF.Interfaces;
using Confluent.Kafka;
using System.Text.Json;

namespace Concursus.API.Services
{
    public class KafkaEmployeeSubscriberService : BackgroundService
    {
        private readonly ILogger<KafkaEmployeeSubscriberService> _logger;
        private readonly IEmployeeSyncService _employeeSyncService;
        private readonly IConsumer<string, string> _consumer;

        public KafkaEmployeeSubscriberService(ILogger<KafkaEmployeeSubscriberService> logger,
                                                  IConfiguration config,
                                                  IEmployeeSyncService employeeSyncService)
        {
            _logger = logger;
            _employeeSyncService = employeeSyncService;
            var consumerConfig = new ConsumerConfig
            {
                BootstrapServers = config["Kafka:BootstrapServers"],
                GroupId = "cymbuild-mdm-subscription",
                AutoOffsetReset = AutoOffsetReset.Latest
            };
            _consumer = new ConsumerBuilder<string, string>(consumerConfig).Build();
            _consumer.Subscribe("mdm_employee_to_cymbuild");
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var result = _consumer.Consume(stoppingToken);
                    var dto = JsonSerializer.Deserialize<EmployeeKafkaDto>(result.Message.Value);
                    if (dto?.Division == "Building and Real Estate")
                    {
                        await _employeeSyncService.ProcessEmployeeAsync(dto);
                        _consumer.Commit(result);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing Kafka employee message.");
                }
            }
        }
    }
}