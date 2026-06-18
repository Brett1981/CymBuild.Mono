namespace Concursus.API.Client.Models.Finance;

public sealed class InvoiceScheduleConfigurationTotalsModel
{
    public decimal MonthlyTotalAmount { get; set; }
    public decimal PercentageTotalPercentage { get; set; }
    public decimal PercentageTotalAmount { get; set; }
    public decimal ScheduleAmount { get; set; }
}