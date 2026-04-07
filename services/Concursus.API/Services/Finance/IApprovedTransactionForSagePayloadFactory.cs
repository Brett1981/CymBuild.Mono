#nullable enable

using Concursus.Common.Shared.Models.Finance;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Builds the final wrapper request DTO and the exact JSON payload that will be sent
    /// to POST /api/sales-orders.
    ///
    /// Phase 5 purpose:
    /// - Keep the mapper responsible for object-to-object mapping only
    /// - Keep payload serialization in one deterministic place
    /// - Make Phase 6 payload persistence use the exact same JSON that is posted outbound
    /// </summary>
    public interface IApprovedTransactionForSagePayloadFactory
    {
        /// <summary>
        /// Builds the final wrapper request DTO from the approved transaction read model.
        /// </summary>
        SageCreateSalesOrderRequest Build(ApprovedTransactionForSageReadModel source);

        /// <summary>
        /// Builds the exact JSON payload that will be posted to the Sage REST-wrapper.
        /// </summary>
        string BuildJson(ApprovedTransactionForSageReadModel source);
    }
}