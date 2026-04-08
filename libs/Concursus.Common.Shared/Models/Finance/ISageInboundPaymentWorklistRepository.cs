#nullable enable

namespace Concursus.Common.Shared.Models.Finance
{
    public interface ISageInboundPaymentWorklistRepository
    {
        Task<IReadOnlyList<SageInboundPaymentWorklistItem>> GetWorklistAsync(
            int batchSize,
            int claimStaleAfterMinutes,
            CancellationToken cancellationToken = default);

        Task EnqueueAsync(
            Guid cymBuildDocumentGuid,
            bool forceRequeue,
            CancellationToken cancellationToken = default);
    }
}