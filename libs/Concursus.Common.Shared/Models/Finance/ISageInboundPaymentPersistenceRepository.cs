#nullable enable

using System.Threading;
using System.Threading.Tasks;

namespace Concursus.Common.Shared.Models.Finance
{
    public interface ISageInboundPaymentPersistenceRepository
    {
        Task<long> UpsertExternalTransactionAsync(
            SageExternalTransactionUpsertRequest request,
            CancellationToken cancellationToken = default);

        Task<long> UpsertExternalAllocationAsync(
            SageExternalAllocationUpsertRequest request,
            CancellationToken cancellationToken = default);

        Task<SageReconcileInvoiceResult> ReconcileInvoiceAsync(
            long externalTransactionId,
            CancellationToken cancellationToken = default);

        Task<SageReconcileAllocationResult> ReconcileAllocationAsync(
            long externalAllocationId,
            CancellationToken cancellationToken = default);

        Task ApplyInvoicePaymentStatusAsync(
            int invoiceRequestId,
            CancellationToken cancellationToken = default);
    }
}