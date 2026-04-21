using System;
using System.Threading;
using System.Threading.Tasks;
using Concursus.Common.Shared.Models.Finance;
using Concursus.Common.Shared.Services.Finance;

namespace Concursus.API.Services.Finance
{
    public sealed class TransactionToSageIdempotencyService : ITransactionToSageIdempotencyService
    {
        private readonly ITransactionToSageIdempotencyRepository _repository;

        public TransactionToSageIdempotencyService(
            ITransactionToSageIdempotencyRepository repository)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        }

        public Task<TransactionToSageIdempotencyStatus> GetStatusAsync(
            Guid transactionGuid,
            CancellationToken cancellationToken = default)
        {
            return _repository.GetStatusAsync(
                transactionGuid,
                cancellationToken);
        }

        public Task<TransactionToSageIdempotencyClaimResult> TryClaimAsync(
            long transactionId,
            Guid transactionGuid,
            Guid transitionGuid,
            int updatedByUserId,
            int claimTimeoutMinutes,
            CancellationToken cancellationToken = default)
        {
            return _repository.TryClaimAsync(
                transactionId,
                transactionGuid,
                transitionGuid,
                updatedByUserId,
                claimTimeoutMinutes,
                cancellationToken);
        }

        public Task MarkSuccessAsync(
            Guid transactionGuid,
            Guid transitionGuid,
            string sageOrderId,
            string sageOrderNumber,
            string sageDataSet,
            string responseStatus,
            string responseDetail,
            string requestPayloadJson,
            string responsePayloadJson,
            int updatedByUserId,
            CancellationToken cancellationToken = default)
        {
            return _repository.MarkSuccessAsync(
                transactionGuid,
                transitionGuid,
                sageOrderId,
                sageOrderNumber,
                sageDataSet,
                responseStatus,
                responseDetail,
                requestPayloadJson,
                responsePayloadJson,
                updatedByUserId,
                cancellationToken);
        }

        public Task MarkFailureAsync(
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
            return _repository.MarkFailureAsync(
                transactionGuid,
                transitionGuid,
                errorMessage,
                isRetryable,
                responseStatus,
                responseDetail,
                requestPayloadJson,
                responsePayloadJson,
                updatedByUserId,
                cancellationToken);
        }
    }
}