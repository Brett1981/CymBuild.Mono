#nullable enable

using Concursus.API.Sage.SOAP;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Concursus.API.Services.Finance
{
    public sealed class SageInboundPaymentSyncWorker : BackgroundService
    {
        private readonly ILogger<SageInboundPaymentSyncWorker> _logger;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly IOptionsMonitor<SageInboundPaymentSyncWorkerOptions> _workerOptions;
        private readonly IOptionsMonitor<SageApiOptions> _sageApiOptions;

        public SageInboundPaymentSyncWorker(
            ILogger<SageInboundPaymentSyncWorker> logger,
            IServiceScopeFactory scopeFactory,
            IOptionsMonitor<SageInboundPaymentSyncWorkerOptions> workerOptions,
            IOptionsMonitor<SageApiOptions> sageApiOptions)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _scopeFactory = scopeFactory ?? throw new ArgumentNullException(nameof(scopeFactory));
            _workerOptions = workerOptions ?? throw new ArgumentNullException(nameof(workerOptions));
            _sageApiOptions = sageApiOptions ?? throw new ArgumentNullException(nameof(sageApiOptions));
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("SageInboundPaymentSyncWorker started.");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var workerOptions = _workerOptions.CurrentValue;
                    var sageOptions = _sageApiOptions.CurrentValue;

                    if (!workerOptions.Enabled || !sageOptions.Enabled)
                    {
                        await DelayAsync(workerOptions.IntervalSeconds, stoppingToken).ConfigureAwait(false);
                        continue;
                    }

                    using var scope = _scopeFactory.CreateScope();

                    var worklistRepository = scope.ServiceProvider.GetRequiredService<ISageInboundPaymentWorklistRepository>();
                    var syncService = scope.ServiceProvider.GetRequiredService<ISageInboundPaymentSyncService>();

                    var workItems = await worklistRepository.GetWorklistAsync(
                        workerOptions.BatchSize,
                        workerOptions.ClaimStaleAfterMinutes,
                        stoppingToken).ConfigureAwait(false);

                    if (workItems.Count > 0)
                    {
                        _logger.LogInformation(
                            "SageInboundPaymentSyncWorker found {Count} work item(s).",
                            workItems.Count);
                    }

                    foreach (var workItem in workItems)
                    {
                        if (stoppingToken.IsCancellationRequested)
                            break;

                        try
                        {
                            var result = await syncService.SyncAsync(
                                workItem.CymBuildDocumentGuid,
                                force: false,
                                stoppingToken).ConfigureAwait(false);

                            if (!result.IsSuccess)
                            {
                                _logger.LogWarning(
                                    "Sage inbound payment sync did not succeed for {DocumentGuid}. Retryable: {Retryable}. Message: {Message}",
                                    workItem.CymBuildDocumentGuid,
                                    result.IsRetryableFailure,
                                    result.Message);
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(
                                ex,
                                "Unhandled worker error while syncing inbound Sage payments for {DocumentGuid}.",
                                workItem.CymBuildDocumentGuid);
                        }
                    }

                    await DelayAsync(workerOptions.IntervalSeconds, stoppingToken).ConfigureAwait(false);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Unhandled error in SageInboundPaymentSyncWorker.");
                    await DelayAsync(_workerOptions.CurrentValue.IntervalSeconds, stoppingToken).ConfigureAwait(false);
                }
            }

            _logger.LogInformation("SageInboundPaymentSyncWorker stopped.");
        }

        private static Task DelayAsync(int intervalSeconds, CancellationToken cancellationToken)
        {
            var safeIntervalSeconds = intervalSeconds > 0 ? intervalSeconds : 60;
            return Task.Delay(TimeSpan.FromSeconds(safeIntervalSeconds), cancellationToken);
        }
    }
}