namespace Concursus.API.Sage.SOAP.Models
{
    public sealed class SageFetchSalesOrdersResponse
    {
        public string? Status { get; set; }
        public string? Detail { get; set; }
        public List<Dictionary<string, object?>> SalesOrders { get; set; } = new();
    }
}
