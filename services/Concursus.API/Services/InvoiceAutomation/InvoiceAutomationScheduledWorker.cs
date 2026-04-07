using Microsoft.Extensions.Options;

namespace Concursus.API.Services.InvoiceAutomation;

/// <summary>
/// Scheduled worker:
/// - Runs Phase 4 materialisation (consistency sweep) to ensure ACT/MS TriggerInstances exist
/// - Runs Phase 4→6 orchestrator to create InvoiceRequests (MonthConfig + TriggerInstances + PercentageConfig) and batch them
///
/// RIBA automation remains “present but on hold” because detectors/instances can exist,
/// but you control whether/how they become completed. This worker does not special-case RIBA.
/// </summary>
public sealed class InvoiceAutomationScheduledWorker : BackgroundService
{
    private readonly InvoiceAutomationRepository _repo;
    private readonly IOptionsMonitor<InvoiceAutomationOptions> _options;
    private readonly ILogger<InvoiceAutomationScheduledWorker> _logger;

    public InvoiceAutomationScheduledWorker(
        InvoiceAutomationRepository repo,
        IOptionsMonitor<InvoiceAutomationOptions> options,
        ILogger<InvoiceAutomationScheduledWorker> logger)
    {
        _repo = repo;
        _options = options;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("InvoiceAutomationScheduledWorker starting.");

        // Log the effective options once at startup (proves binding is working)
        var startOpt = _options.CurrentValue;
        _logger.LogInformation(
            "InvoiceAutomation options: Enabled={Enabled}, IntervalSeconds={Interval}, RequesterUserGuid={Requester}, LockName={LockName}, LockTimeoutMs={Timeout}",
            startOpt.Enabled, startOpt.IntervalSeconds, startOpt.RequesterUserGuid, startOpt.SqlAppLockName, startOpt.SqlAppLockTimeoutMs);

        while (!stoppingToken.IsCancellationRequested)
        {
            var opt = _options.CurrentValue;

            try
            {
                if (!opt.Enabled)
                {
                    await DelaySafe(opt.IntervalSeconds, stoppingToken);
                    continue;
                }

                if (opt.RequesterUserGuid == Guid.Empty)
                {
                    _logger.LogError("InvoiceAutomation is enabled but RequesterUserGuid is empty. Disabling this tick.");
                    await DelaySafe(opt.IntervalSeconds, stoppingToken);
                    continue;
                }

                await _repo.WithExclusiveAppLockAsync(
                    lockName: opt.SqlAppLockName,
                    timeoutMs: opt.SqlAppLockTimeoutMs,
                    action: async (conn, tx, ct) =>
                    {
                        var nowUtc = DateTime.UtcNow;

                        if (opt.RunMaterialiseSweepEachTick)
                        {
                            var (ins, upd, attempt) = await _repo.MaterialiseTriggerInstancesAsync(
                                conn, detectedUtc: nowUtc, maxAttempts: 5, ct: ct);

                            if (ins > 0 || upd > 0)
                                _logger.LogInformation("Phase4 materialisation: inserted={Inserted}, updated={Updated}, attempt={Attempt}", ins, upd, attempt);
                        }

                        var nudges = await _repo.DequeueNudgesAsync(conn, take: 50, ct: ct);
                        if (nudges > 0)
                            _logger.LogInformation("Invoice automation nudges dequeued: {Count}", nudges);

                        var runGuid = Guid.NewGuid();
                        await _repo.RunPhase4To6Async(
                            conn,
                            runGuid: runGuid,
                            requesterUserGuid: opt.RequesterUserGuid,
                            defaultPaymentStatusGuid: opt.DefaultPaymentStatusGuid,
                            notes: opt.Notes,
                            nowUtc: nowUtc,
                            ct: ct);
                    },
                    ct: stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                // normal shutdown
            }
            catch (Exception ex)
            {
                // IMPORTANT: this is the line that will tell you if it's RequesterUserGuid / identity missing / SQL error etc.
                _logger.LogError(ex, "InvoiceAutomationScheduledWorker tick failed.");
            }

            await DelaySafe(_options.CurrentValue.IntervalSeconds, stoppingToken);
        }

        _logger.LogInformation("InvoiceAutomationScheduledWorker stopping.");
    }

    private static async Task DelaySafe(int intervalSeconds, CancellationToken ct)
    {
        if (intervalSeconds <= 0) intervalSeconds = 300;
        await Task.Delay(TimeSpan.FromSeconds(intervalSeconds), ct);
    }
}