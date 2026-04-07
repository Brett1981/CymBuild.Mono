#nullable enable

using System.Threading;
using System.Threading.Tasks;
using Concursus.Common.Shared.Models.Finance;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Orchestrates Phase 5 approved transaction submission to the Sage REST-wrapper.
    /// </summary>
    public interface ITransactionToSageSubmissionService
    {
        Task<TransactionToSageProcessResult> ProcessApprovedTransactionAsync(
            string outboxPayloadJson,
            CancellationToken cancellationToken = default);
    }
}