namespace Concursus.API.Client.Models.Finance;

public sealed class InvoiceScheduleDrawdownBulkEditRowModel
{
    public Guid Guid { get; set; }
    public int PeriodNumber { get; set; }
    public decimal Amount { get; set; }
    public decimal Percentage { get; set; }
    public DateTime? OnDayOfMonth { get; set; }
    public string Description { get; set; } = string.Empty;
    public Guid? RibaStageGuid { get; set; }
}