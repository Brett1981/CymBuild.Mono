#nullable enable

using System.Threading;
using System.Threading.Tasks;
using Concursus.Common.Shared.Models.Finance;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Dedicated boundary for wrapper sales-order submission.
    /// </summary>
    public interface ISageSalesOrderGateway
    {
        Task<SageCreateSalesOrderResponse> CreateSalesOrderAsync(
            SageCreateSalesOrderRequest request,
            CancellationToken cancellationToken = default);
    }
}