namespace Concursus.API.Services.InvoiceAutomation;

public sealed class InvoiceAutomationOptions
{
    public bool Enabled { get; set; } = true;

    /// <summary>
    /// How often to run the scheduled automation loop (monthly + percentage + triggerinstances creation).
    /// Recommended: 300s (5 mins) in UAT/PROD, 60s in DEV while testing.
    /// </summary>
    public int IntervalSeconds { get; set; } = 300;

    /// <summary>
    /// Must exist in SCore.Identities.Guid (service identity).
    /// Required by SFin.InvoiceAutomation_Run_Phase4To6.
    /// </summary>
    public Guid RequesterUserGuid { get; set; } = Guid.Empty;

    /// <summary>
    /// Optional. If null, the SQL procs pick the lowest active InvoicePaymentStatus.
    /// </summary>
    public Guid? DefaultPaymentStatusGuid { get; set; }

    public string Notes { get; set; } = "Scheduled automation run";

    /// <summary>
    /// SQL Server application lock name to prevent multi-instance concurrency.
    /// </summary>
    public string SqlAppLockName { get; set; } = "SFin.InvoiceAutomation.ScheduledWorker";

    public int SqlAppLockTimeoutMs { get; set; } = 2000;

    /// <summary>
    /// If true, each tick runs Phase 4 materialisation (detect ACT/MS, write TriggerInstances).
    /// This is your “consistency sweep”.
    /// </summary>
    public bool RunMaterialiseSweepEachTick { get; set; } = true;
}