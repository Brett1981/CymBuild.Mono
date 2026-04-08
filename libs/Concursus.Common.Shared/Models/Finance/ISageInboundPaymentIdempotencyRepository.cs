#nullable enable

using System;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.Common.Shared.Models.Finance
{
    public interface ISageInboundPaymentIdempotencyRepository
    {
        Task<SageInboundStatusEnsureResult> EnsureAsync(
            SageInboundSyncTarget target,
            CancellationToken cancellationToken = default);

        Task<SageInboundClaimResult> TryClaimAsync(
            Guid cymBuildDocumentGuid,
            CancellationToken cancellationToken = default);

        Task MarkSuccessAsync(
            Guid cymBuildDocumentGuid,
            DateTime? lastSourceWatermarkUtc,
            CancellationToken cancellationToken = default);

        Task MarkFailureAsync(
            Guid cymBuildDocumentGuid,
            string errorMessage,
            bool isRetryable,
            CancellationToken cancellationToken = default);

        Task InsertAttemptAsync(
            long inboundStatusId,
            Guid cymBuildDocumentGuid,
            long cymBuildDocumentId,
            string operationName,
            DateTime attemptedOnUtc,
            DateTime? completedOnUtc,
            bool isSuccess,
            bool isRetryableFailure,
            string responseStatus,
            string? responseDetail,
            string? errorMessage,
            string? requestPayloadJson,
            string? responsePayloadJson,
            CancellationToken cancellationToken = default);
    }
}