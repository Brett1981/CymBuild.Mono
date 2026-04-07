using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Sage.SOAP.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Concursus.API.Sage.SOAP.Client
{
    public sealed class FeatureToggledSageApiClient : ISageApiClient
    {
        private readonly SageApiClient _inner;
        private readonly IOptionsMonitor<SageApiOptions> _options;
        private readonly ILogger<FeatureToggledSageApiClient> _logger;

        public FeatureToggledSageApiClient(
            SageApiClient inner,
            IOptionsMonitor<SageApiOptions> options,
            ILogger<FeatureToggledSageApiClient> logger)
        {
            _inner = inner;
            _options = options;
            _logger = logger;
        }

        private bool IsEnabled => _options.CurrentValue.Enabled;

        public Task<string> GetHealthAsync(CancellationToken cancellationToken = default)
        {
            if (!IsEnabled)
            {
                _logger.LogInformation("Sage disabled - skipping health check");
                return Task.FromResult("disabled");
            }

            return _inner.GetHealthAsync(cancellationToken);
        }

        public Task<SageCreateSalesOrderResponse?> CreateSalesOrderAsync(
            SageCreateSalesOrderRequest request,
            CancellationToken cancellationToken = default)
        {
            if (!IsEnabled)
            {
                _logger.LogInformation("Sage disabled - skipping CreateSalesOrder");

                return Task.FromResult<SageCreateSalesOrderResponse?>(new()
                {
                    Status = "Disabled",
                    Detail = "Sage integration is disabled"
                });
            }

            return _inner.CreateSalesOrderAsync(request, cancellationToken);
        }

        public Task<SageFetchSalesOrdersResponse?> FetchSalesOrdersAsync(
            SageDataset dataset,
            string orderId,
            string? filterOperator = null,
            bool force = false,
            CancellationToken cancellationToken = default)
        {
            if (!IsEnabled)
            {
                _logger.LogInformation("Sage disabled - skipping FetchSalesOrders");

                return Task.FromResult<SageFetchSalesOrdersResponse?>(new()
                {
                    Status = "Disabled",
                    Detail = "Sage integration is disabled",
                    SalesOrders = new()
                });
            }

            return _inner.FetchSalesOrdersAsync(dataset, orderId, filterOperator, force, cancellationToken);
        }

        public Task<SageFetchCustomerTransactionsResponse?> FetchCustomerTransactionsAsync(
            SageDataset dataset,
            string? accountReference = null,
            string? documentNo = null,
            int? sysTraderTranType = null,
            bool force = false,
            CancellationToken cancellationToken = default)
        {
            if (!IsEnabled)
            {
                _logger.LogInformation("Sage disabled - skipping FetchCustomerTransactions");

                return Task.FromResult<SageFetchCustomerTransactionsResponse?>(new()
                {
                    Status = "Disabled",
                    Detail = "Sage integration is disabled",
                    Transactions = new()
                });
            }

            return _inner.FetchCustomerTransactionsAsync(
                dataset,
                accountReference,
                documentNo,
                sysTraderTranType,
                force,
                cancellationToken);
        }
    }
}