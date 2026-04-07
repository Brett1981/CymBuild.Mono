namespace Concursus.API.Sage.SOAP.Models
{
    public sealed class SageCreateSalesOrderRequest
    {
        public SageDataset Dataset { get; set; }
        public string AccountReference { get; set; } = string.Empty;
        public string? CustomerOrderNo { get; set; }
        public string? DocumentDate { get; set; }
        public bool? UseInvoiceAddress { get; set; }
        public bool? OverrideOnHold { get; set; }
        public bool? AllowCreditLimitException { get; set; }
        public string? AnalysisCode01Value { get; set; }
        public string? AnalysisCode02Value { get; set; }
        public string? AnalysisCode03Value { get; set; }
        public List<SageSalesOrderLine> Lines { get; set; } = new();
    }
}
