#nullable enable

namespace Concursus.Common.Shared.Models.Finance
{
    public interface ISageInboundPaymentSyncService
    {
        Task<SageInboundPaymentSyncResult> SyncAsync(
            SageInboundPaymentSyncRequest request,
            CancellationToken cancellationToken = default);

        Task<SageInboundPaymentSyncResult> SyncAsync(
            Guid cymBuildDocumentGuid,
            bool force,
            CancellationToken cancellationToken = default);

        Task<SageInboundPaymentSyncEnqueueResult> EnqueueAsync(
            SageInboundPaymentSyncEnqueueRequest request,
            CancellationToken cancellationToken = default);

        Task<SageInboundPaymentSyncEnqueueResult> EnqueueAsync(
            Guid cymBuildDocumentGuid,
            bool forceRequeue,
            CancellationToken cancellationToken = default);
    }
}