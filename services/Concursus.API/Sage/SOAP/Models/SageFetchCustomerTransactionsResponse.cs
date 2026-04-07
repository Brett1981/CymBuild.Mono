namespace Concursus.API.Sage.SOAP.Models
{
    public sealed class SageFetchCustomerTransactionsResponse
    {
        public string? Status { get; set; }
        public string? Detail { get; set; }
        public List<Dictionary<string, object?>> Transactions { get; set; } = new();
    }
}
