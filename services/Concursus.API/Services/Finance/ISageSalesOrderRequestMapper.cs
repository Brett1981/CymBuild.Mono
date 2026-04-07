#nullable enable

using Concursus.Common.Shared.Models.Finance;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Maps an approved CymBuild transaction read model to the Sage REST-wrapper sales-order contract.
    /// </summary>
    public interface ISageSalesOrderRequestMapper
    {
        SageCreateSalesOrderRequest Map(ApprovedTransactionForSageReadModel source);
    }
}