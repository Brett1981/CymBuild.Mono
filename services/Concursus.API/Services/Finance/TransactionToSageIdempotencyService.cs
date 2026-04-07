using Concursus.Common.Shared.Models.Finance;
using Concursus.Common.Shared.Services.Finance;
using Microsoft.Extensions.Logging;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Default application service for transaction submission idempotency against the Sage REST wrapper.
    /// </summary>
    public sealed class TransactionToSageIdempotencyService : ITransactionToSageIdempotencyService
    {
        private readonly ITransactionToSageIdempotencyRepository _repository;
        private readonly ILogger<TransactionToSageIdempotencyService> _logger;

        public TransactionToSageIdempotencyService(
            ITransactionToSageIdempotencyRepository repository,
            ILogger<TransactionToSageIdempotencyService> logger)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public Task<TransactionToSageIdempotencyStatus> GetStatusAsync(
            Guid transactionGuid,
            CancellationToken cancellationToken = default)
        {
            if (transactionGuid == Guid.Empty)
            {
                throw new ArgumentException("Transaction guid cannot be empty.", nameof(transactionGuid));
            }

            return _repository.GetStatusAsync(transactionGuid, cancellationToken);
        }

        public async Task<TransactionToSageIdempotencyClaimResult> TryClaimAsync(
            long transactionId,
            Guid transactionGuid,
            Guid transitionGuid,
            int updatedByUserId,
            int claimTimeoutMinutes,
            CancellationToken cancellationToken = default)
        {
            if (transactionId <= 0)
            {
                throw new ArgumentException("Transaction id must be greater than zero.", nameof(transactionId));
            }

            if (transactionGuid == Guid.Empty)
            {
                throw new ArgumentException("Transaction guid cannot be empty.", nameof(transactionGuid));
            }

            if (transitionGuid == Guid.Empty)
            {
                throw new ArgumentException("Transition guid cannot be empty.", nameof(transitionGuid));
            }

            if (claimTimeoutMinutes <= 0)
            {
                throw new ArgumentException("Claim timeout minutes must be greater than zero.", nameof(claimTimeoutMinutes));
            }

            TransactionToSageIdempotencyClaimResult result = await _repository.TryClaimAsync(
                transactionId,
                transactionGuid,
                transitionGuid,
                updatedByUserId,
                claimTimeoutMinutes,
                cancellationToken);

            _logger.LogInformation(
                "Sage submission claim result. TransactionId={TransactionId}, TransactionGuid={TransactionGuid}, TransitionGuid={TransitionGuid}, ClaimAcquired={ClaimAcquired}, AlreadyProcessed={AlreadyProcessed}, InProgressElsewhere={InProgressElsewhere}, StaleClaimReclaimed={StaleClaimReclaimed}, StatusCode={StatusCode}",
                transactionId,
                transactionGuid,
                transitionGuid,
                result.ClaimAcquired,
                result.AlreadyProcessed,
                result.InProgressElsewhere,
                result.StaleClaimReclaimed,
                result.StatusCode);

            return result;
        }

        public async Task MarkSuccessAsync(
            Guid transactionGuid,
            Guid transitionGuid,
            string sageOrderId,
            string sageOrderNumber,
            string responseStatus,
            string responseDetail,
            string requestPayloadJson,
            string responsePayloadJson,
            int updatedByUserId,
            CancellationToken cancellationToken = default)
        {
            if (transactionGuid == Guid.Empty)
            {
                throw new ArgumentException("Transaction guid cannot be empty.", nameof(transactionGuid));
            }

            if (transitionGuid == Guid.Empty)
            {
                throw new ArgumentException("Transition guid cannot be empty.", nameof(transitionGuid));
            }

            await _repository.MarkSuccessAsync(
                transactionGuid,
                transitionGuid,
                sageOrderId ?? string.Empty,
                sageOrderNumber ?? string.Empty,
                responseStatus ?? string.Empty,
                responseDetail ?? string.Empty,
                requestPayloadJson ?? string.Empty,
                responsePayloadJson ?? string.Empty,
                updatedByUserId,
                cancellationToken);

            _logger.LogInformation(
                "Sage submission marked successful. TransactionGuid={TransactionGuid}, TransitionGuid={TransitionGuid}, SageOrderId={SageOrderId}, SageOrderNumber={SageOrderNumber}",
                transactionGuid,
                transitionGuid,
                sageOrderId,
                sageOrderNumber);
        }

        public async Task MarkFailureAsync(
            Guid transactionGuid,
            Guid transitionGuid,
            string errorMessage,
            bool isRetryable,
            string responseStatus,
            string responseDetail,
            string requestPayloadJson,
            string responsePayloadJson,
            int updatedByUserId,
            CancellationToken cancellationToken = default)
        {
            if (transactionGuid == Guid.Empty)
            {
                throw new ArgumentException("Transaction guid cannot be empty.", nameof(transactionGuid));
            }

            if (transitionGuid == Guid.Empty)
            {
                throw new ArgumentException("Transition guid cannot be empty.", nameof(transitionGuid));
            }

            await _repository.MarkFailureAsync(
                transactionGuid,
                transitionGuid,
                errorMessage ?? string.Empty,
                isRetryable,
                responseStatus ?? string.Empty,
                responseDetail ?? string.Empty,
                requestPayloadJson ?? string.Empty,
                responsePayloadJson ?? string.Empty,
                updatedByUserId,
                cancellationToken);

            _logger.LogWarning(
                "Sage submission marked failed. TransactionGuid={TransactionGuid}, TransitionGuid={TransitionGuid}, IsRetryable={IsRetryable}, Error={Error}",
                transactionGuid,
                transitionGuid,
                isRetryable,
                errorMessage);
        }
    }
}