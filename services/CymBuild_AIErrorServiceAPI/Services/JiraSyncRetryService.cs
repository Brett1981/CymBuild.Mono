using Microsoft.EntityFrameworkCore;

namespace CymBuild_AIErrorServiceAPI.Services
{
    public class JiraSyncRetryService : BackgroundService
    {
        private readonly IServiceProvider _services;
        private readonly ILogger<JiraSyncRetryService> _logger;

        public JiraSyncRetryService(IServiceProvider services, ILogger<JiraSyncRetryService> logger)
        {
            _services = services;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                using var scope = _services.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AiErrorDbContext>();
                var jira = scope.ServiceProvider.GetRequiredService<JiraTicketService>();
                var config = scope.ServiceProvider.GetRequiredService<IConfiguration>();

                if (!config.GetValue<bool>("Jira:Enabled"))
                {
                    await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
                    continue;
                }

                var unsynced = await db.AiErrorReports
                    .Where(x => !x.JiraTicketCreated)
                    .Take(10)
                    .ToListAsync();

                foreach (var report in unsynced)
                {
                    try
                    {
                        var (key, url, status) = await jira.CreateTicketAsync(
                            $"[CB-AI-{report.Hash.Substring(0, 8)}] CymBuild Error",
                            $"{report.JiraDescription}",
                            $"{report.AiAnalysis}\n\n{report.StackTrace}\n\n{report.ContextJson}"
                        );

                        report.JiraTicketKey = key;
                        report.JiraUrl = url;
                        report.JiraStatus = status;
                        report.JiraTicketCreated = true;
                        report.JiraLastSyncedUtc = DateTime.UtcNow;
                        await db.SaveChangesAsync();
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning($"Retry sync failed for {report.Hash}: {ex.Message}");
                    }
                }

                await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
            }
        }
    }
}