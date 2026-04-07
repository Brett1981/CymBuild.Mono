using Concursus.API.Sage.SOAP.Models;

namespace Concursus.API.Sage.SOAP.Interface
{
    public interface ISageApiClient
    {
        Task<string> GetHealthAsync(CancellationToken cancellationToken = default);

        Task<SageCreateSalesOrderResponse?> CreateSalesOrderAsync(
            SageCreateSalesOrderRequest request,
            CancellationToken cancellationToken = default);

        Task<SageFetchSalesOrdersResponse?> FetchSalesOrdersAsync(
            SageDataset dataset,
            string orderId,
            string? filterOperator = null,
            bool force = false,
            CancellationToken cancellationToken = default);

        Task<SageFetchCustomerTransactionsResponse?> FetchCustomerTransactionsAsync(
            SageDataset dataset,
            string? accountReference = null,
            string? documentNo = null,
            int? sysTraderTranType = null,
            bool force = false,
            CancellationToken cancellationToken = default);
    }
}
