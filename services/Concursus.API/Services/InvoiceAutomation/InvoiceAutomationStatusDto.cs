// File: Services/InvoiceAutomation/InvoiceAutomationStatusDto.cs
namespace Concursus.API.Services.InvoiceAutomation;

public sealed class InvoiceAutomationStatusDto
{
    public bool OptionsEnabled { get; set; }
    public int IntervalSeconds { get; set; }
    public Guid RequesterUserGuid { get; set; }
    public string SqlAppLockName { get; set; } = "";
    public int SqlAppLockTimeoutMs { get; set; }

    public bool CanAcquireLockNow { get; set; }
    public int? AppLockReturnCode { get; set; }

    public Guid? LastRunGuid { get; set; }
    public DateTime? LastRunStartedUtc { get; set; }
    public DateTime? LastRunCompletedUtc { get; set; }
    public string? LastRunNotes { get; set; }
    public string? LastRunSummary { get; set; }

    public int CompletedTriggerInstancesMissingRequests { get; set; }
}