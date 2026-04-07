using Concursus.Common.Shared.Models.Finance;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Application service enforcing idempotent Sage submission for approved transactions.
    /// </summary>
    public interface ITransactionToSageIdempotencyService
    {
        Task<TransactionToSageIdempotencyStatus> GetStatusAsync(
            Guid transactionGuid,
            CancellationToken cancellationToken = default);

        Task<TransactionToSageIdempotencyClaimResult> TryClaimAsync(
            long transactionId,
            Guid transactionGuid,
            Guid transitionGuid,
            int updatedByUserId,
            int claimTimeoutMinutes,
            CancellationToken cancellationToken = default);

        Task MarkSuccessAsync(
            Guid transactionGuid,
            Guid transitionGuid,
            string sageOrderId,
            string sageOrderNumber,
            string responseStatus,
            string responseDetail,
            string requestPayloadJson,
            string responsePayloadJson,
            int updatedByUserId,
            CancellationToken cancellationToken = default);

        Task MarkFailureAsync(
            Guid transactionGuid,
            Guid transitionGuid,
            string errorMessage,
            bool isRetryable,
            string responseStatus,
            string responseDetail,
            string requestPayloadJson,
            string responsePayloadJson,
            int updatedByUserId,
            CancellationToken cancellationToken = default);
    }
}