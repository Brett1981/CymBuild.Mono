#nullable enable

using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Concursus.API.Sage.SOAP.Models;
using Concursus.Common.Shared.Models.Finance;
using SageCreateSalesOrderRequest = Concursus.Common.Shared.Models.Finance.SageCreateSalesOrderRequest;
using SageCreateSalesOrderResponse = Concursus.Common.Shared.Models.Finance.SageCreateSalesOrderResponse;

namespace Concursus.API.Services.Finance
{
    public interface ISageSalesOrderGateway
    {
        Task<SageCreateSalesOrderResponse> CreateSalesOrderAsync(
            SageCreateSalesOrderRequest request,
            CancellationToken cancellationToken = default);

        Task<IReadOnlyList<Dictionary<string, object?>>> FetchCustomerTransactionsAsync(
            SageDataset dataset,
            string accountReference,
            string documentNo,
            int? sysTraderTranType = null,
            bool force = false,
            CancellationToken cancellationToken = default);
    }
}