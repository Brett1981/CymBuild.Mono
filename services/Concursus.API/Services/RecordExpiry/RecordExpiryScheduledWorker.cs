using Microsoft.Extensions.Options;

namespace Concursus.API.Services.RecordExpiry;

/// <summary>
/// Scheduled worker (CYB-461): records a saved "Expired" status for Quotes past
/// their ExpiryDate and Enquiries whose quotes have all expired or whose quoting
/// deadline has passed, through SSop.ExpireOverdueQuotesAndEnquiries.
/// </summary>
public sealed class RecordExpiryScheduledWorker : BackgroundService
{
    private readonly IRecordExpiryRepository _repo;
    private readonly IOptionsMonitor<RecordExpiryOptions> _options;
    private readonly ILogger<RecordExpiryScheduledWorker> _logger;

    public RecordExpiryScheduledWorker(
        IRecordExpiryRepository repo,
        IOptionsMonitor<RecordExpiryOptions> options,
        ILogger<RecordExpiryScheduledWorker> logger)
    {
        _repo = repo;
        _options = options;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var startOpt = _options.CurrentValue;
        _logger.LogInformation(
            "RecordExpiryScheduledWorker starting: Enabled={Enabled}, IntervalSeconds={Interval}, ServiceUserGuid={ServiceUser}, MaxRecordsPerRun={Max}, NotifyWithinDays={NotifyDays}",
            startOpt.Enabled, startOpt.IntervalSeconds, startOpt.ServiceUserGuid, startOpt.MaxRecordsPerRun, startOpt.NotifyWithinDays);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RunOnceAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                // normal shutdown
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "RecordExpiryScheduledWorker tick failed.");
            }

            await DelaySafe(_options.CurrentValue.IntervalSeconds, stoppingToken);
        }

        _logger.LogInformation("RecordExpiryScheduledWorker stopping.");
    }

    /// <summary>
    /// Runs one expiry pass. Returns null when the pass was skipped by configuration.
    /// </summary>
    internal async Task<RecordExpiryRunResult?> RunOnceAsync(CancellationToken ct)
    {
        var opt = _options.CurrentValue;

        if (!opt.Enabled)
            return null;

        if (opt.ServiceUserGuid == Guid.Empty)
        {
            _logger.LogError("RecordExpiry is enabled but ServiceUserGuid is empty. Skipping this tick.");
            return null;
        }

        var result = await _repo.ExpireOverdueAsync(
            opt.ServiceUserGuid,
            opt.MaxRecordsPerRun,
            opt.NotifyWithinDays,
            opt.CommandTimeoutSeconds,
            ct);

        if (!result.LockAcquired)
        {
            _logger.LogInformation("Record expiry skipped: another run holds the lock.");
            return result;
        }

        if (result.QuotesExpired > 0 || result.EnquiriesExpired > 0)
        {
            _logger.LogInformation(
                "Record expiry: quotes={Quotes}, enquiries={Enquiries}, silent={Silent}, failed={Failed}",
                result.QuotesExpired, result.EnquiriesExpired, result.ExpiredSilently, result.Failures.Count);
        }

        foreach (var failure in result.Failures)
        {
            _logger.LogWarning(
                "Record expiry failed for {RecordType} {RecordGuid}: {Error}",
                failure.RecordType, failure.RecordGuid, failure.ErrorMessage);
        }

        return result;
    }

    private static async Task DelaySafe(int intervalSeconds, CancellationToken ct)
    {
        if (intervalSeconds <= 0) intervalSeconds = 3600;
        await Task.Delay(TimeSpan.FromSeconds(intervalSeconds), ct);
    }
}
