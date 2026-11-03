namespace Concursus.API.Services.RecordExpiry;

/// <summary>
/// Configuration for <see cref="RecordExpiryScheduledWorker"/> (section "RecordExpiry").
/// </summary>
public sealed class RecordExpiryOptions
{
    public const string SectionName = "RecordExpiry";

    public bool Enabled { get; set; } = true;

    /// <summary>
    /// How often to record "Expired" statuses. Expiry is date-based, so hourly is enough.
    /// </summary>
    public int IntervalSeconds { get; set; } = 3600;

    /// <summary>
    /// Must exist in SCore.Identities.Guid (service identity). Recorded as the
    /// creator of each "Expired" transition.
    /// </summary>
    public Guid ServiceUserGuid { get; set; } = Guid.Empty;

    /// <summary>
    /// Maximum Quotes plus Enquiries expired per run, so the historic backlog
    /// clears over several runs instead of one long one.
    /// </summary>
    public int MaxRecordsPerRun { get; set; } = 500;

    /// <summary>
    /// Records that expired more than this many days ago are expired without
    /// notifications, so the first run does not notify for the whole backlog.
    /// </summary>
    public int NotifyWithinDays { get; set; } = 7;

    public int CommandTimeoutSeconds { get; set; } = 600;
}
