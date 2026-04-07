namespace CymBuild_AIErrorServiceAPI.Services
{
    using CymBuild_AIErrorServiceAPI;
    using CymBuild_AIErrorServiceAPI.Models;
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Hosting;
    using Microsoft.Extensions.Logging;
    using System;
    using System.Net.Http;
    using System.Text.Json;
    using System.Threading;
    using System.Threading.Tasks;

    public class JiraSyncSchedulerService : BackgroundService
    {
        private readonly IServiceProvider _services;
        private readonly ILogger<JiraSyncSchedulerService> _logger;
        private Timer? _timer;
        private const int MaxRetries = 2;

        public JiraSyncSchedulerService(IServiceProvider services, ILogger<JiraSyncSchedulerService> logger)
        {
            _services = services;
            _logger = logger;
        }

        protected override Task ExecuteAsync(CancellationToken stoppingToken)
        {
            ScheduleNextRun();
            return Task.CompletedTask;
        }

        private void ScheduleNextRun()
        {
            var now = DateTime.UtcNow;
            var runTime = DateTime.UtcNow.Date.AddHours(6); // 6:00 AM UTC

            if (now > runTime)
                runTime = runTime.AddDays(1); // schedule for next day

            var delay = runTime - now;
            _timer = new Timer(RunSyncWithRetriesAsync, null, delay, Timeout.InfiniteTimeSpan);
            _logger.LogInformation($"[Scheduler] Jira sync scheduled in {delay.TotalMinutes} minutes at {runTime} UTC");
        }

        private async void RunSyncWithRetriesAsync(object? state)
        {
            for (int attempt = 1; attempt <= MaxRetries + 1; attempt++)
            {
                using var scope = _services.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AiErrorDbContext>();
                var httpClientFactory = scope.ServiceProvider.GetRequiredService<IHttpClientFactory>();
                var config = scope.ServiceProvider.GetRequiredService<IConfiguration>();
                var logger = scope.ServiceProvider.GetRequiredService<ILogger<JiraSyncSchedulerService>>();

                var http = httpClientFactory.CreateClient();
                var log = new JiraSyncLog { StartedUtc = DateTime.UtcNow };

                try
                {
                    var baseUrl = config["Kestrel:Endpoints:Https:Url"] ?? "https://localhost:7132";
                    var url = $"{baseUrl}/api/ErrorReport/sync-jira";
                    logger.LogInformation($"[Scheduler] Calling {url}");

                    var response = await http.PostAsync(url, null);
                    var body = await response.Content.ReadAsStringAsync();

                    log.EndedUtc = DateTime.UtcNow;
                    log.Success = response.IsSuccessStatusCode;

                    if (response.IsSuccessStatusCode)
                    {
                        try
                        {
                            var json = JsonSerializer.Deserialize<JsonElement>(body);
                            var inserted = json.GetProperty("inserted").GetInt32();
                            var updated = json.GetProperty("updated").GetInt32();
                            var unchanged = json.GetProperty("unchanged").GetInt32();
                            var deleted = json.TryGetProperty("deleted", out var del) ? del.ToString() : "0";

                            log.Message = $"Inserted: {inserted}, Updated: {updated}, Unchanged: {unchanged}, Deleted: {deleted}";
                        }
                        catch
                        {
                            log.Message = "Completed successfully (unparseable response)";
                        }
                    }
                    else
                    {
                        log.Message = $"HTTP {response.StatusCode}: {body}";
                    }

                    db.JiraSyncLogs.Add(log);
                    await db.SaveChangesAsync();

                    logger.LogInformation($"[Scheduler] Sync attempt #{attempt} status: {log.Success} - {log.Message}");

                    if (log.Success) break; // exit on success
                }
                catch (Exception ex)
                {
                    log.EndedUtc = DateTime.UtcNow;
                    log.Success = false;
                    log.Message = $"Exception: {ex.Message}";

                    db.JiraSyncLogs.Add(log);
                    await db.SaveChangesAsync();

                    logger.LogError(ex, $"[Scheduler] Sync attempt #{attempt} failed.");
                }

                if (attempt <= MaxRetries)
                {
                    logger.LogWarning($"[Scheduler] Waiting 30 min before retry #{attempt + 1}.");
                    await Task.Delay(TimeSpan.FromMinutes(30));
                }
            }

            ScheduleNextRun();
        }

        public override void Dispose()
        {
            _timer?.Dispose();
            base.Dispose();
        }
    }
}