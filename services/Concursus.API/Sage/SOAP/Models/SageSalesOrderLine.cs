namespace Concursus.API.Sage.SOAP.Models
{
    public sealed class SageSalesOrderLine
    {
        public string ItemDescription { get; set; } = string.Empty;
        public string NominalRef { get; set; } = string.Empty;
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public string? LineType { get; set; }
        public string? NominalCC { get; set; }
        public string? NominalDept { get; set; }
        public int? TaxCode { get; set; }
    }
}
