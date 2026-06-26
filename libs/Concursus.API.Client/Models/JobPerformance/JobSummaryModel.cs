using static Concursus.API.Client.FormHelper;

namespace Concursus.API.Client.Models.JobPerformance;

public sealed class JobSummaryModel
{
    public long JobId { get; set; }
    public Guid JobGuid { get; set; }
    public int RowStatus { get; set; }
    public string Number { get; set; } = string.Empty;
    public string DisplayTitle { get; set; } = string.Empty;
    public string JobDescription { get; set; } = string.Empty;
    public string ClientName { get; set; } = string.Empty;
    public string SurveyorName { get; set; } = string.Empty;
    public int CurrentStatusId { get; set; }
    public Guid CurrentStatusGuid { get; set; }
    public string CurrentStatusName { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public bool IsComplete { get; set; }
    public bool IsCancelled { get; set; }
    public bool CannotBeInvoiced { get; set; }
    public InvoiceProcessingModeUi InvoiceProcessingMode { get; set; } = InvoiceProcessingModeUi.Manual;
    public int OpenMilestoneCount { get; set; }
    public int OpenActivityCount { get; set; }
    public int OpenActionCount { get; set; }
    public int PendingInvoiceRequestCount { get; set; }
    public int ActiveInvoiceScheduleCount { get; set; }
    public bool CanCreateReplacementInvoiceSchedule { get; set; }
    public JobFinancialOverviewModel FinancialOverview { get; set; } = new();
}
