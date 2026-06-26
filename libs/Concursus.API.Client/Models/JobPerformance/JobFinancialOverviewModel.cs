namespace Concursus.API.Client.Models.JobPerformance;

public sealed class JobFinancialOverviewModel
{
    public Guid JobGuid { get; set; }
    public decimal AgreedFeeTotal { get; set; }
    public decimal AgreedFeeIncludingCap { get; set; }
    public decimal ScheduledTotal { get; set; }
    public decimal InvoiceRequestPendingTotal { get; set; }
    public decimal InvoicedNet { get; set; }
    public decimal InvoicedGross { get; set; }
    public decimal PaidNet { get; set; }
    public decimal PaidGross { get; set; }
    public decimal RemainingNet { get; set; }
    public int ActiveInvoiceScheduleCount { get; set; }
    public int SystemGeneratedManualScheduleCount { get; set; }
    public int PendingInvoiceRequestCount { get; set; }
    public int ReconciliationRequiredInvoiceRequestCount { get; set; }
    public int BlockedInvoiceRequestCount { get; set; }
    public bool CanCreateReplacementInvoiceSchedule { get; set; }
}
