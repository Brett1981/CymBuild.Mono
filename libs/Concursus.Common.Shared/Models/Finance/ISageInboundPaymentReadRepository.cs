#nullable enable

namespace Concursus.Common.Shared.Models.Finance
{
    public interface ISageInboundPaymentReadRepository
    {
        Task<SageInboundSyncTarget?> GetSyncTargetAsync(
            Guid cymBuildDocumentGuid,
            CancellationToken cancellationToken = default);
    }
}