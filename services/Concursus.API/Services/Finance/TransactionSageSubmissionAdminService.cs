using Concursus.Common.Shared.Models.Finance;
using Concursus.Common.Shared.Services.Finance;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.API.Services.Finance
{
    public sealed class TransactionSageSubmissionAdminService : ITransactionSageSubmissionAdminService
    {
        private readonly ITransactionSageSubmissionAdminRepository _repository;
        private readonly ILogger<TransactionSageSubmissionAdminService> _logger;

        public TransactionSageSubmissionAdminService(
            ITransactionSageSubmissionAdminRepository repository,
            ILogger<TransactionSageSubmissionAdminService> logger)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<TransactionSageSubmissionRequeueResult> RequeueAsync(
            IReadOnlyCollection<Guid> transactionGuids,
            bool includeNonRetryableFailures = false,
            CancellationToken cancellationToken = default)
        {
            var result = await _repository.RequeueAsync(
                transactionGuids,
                includeNonRetryableFailures,
                cancellationToken);

            _logger.LogInformation(
                "Transaction Sage submission reset executed. IncludeNonRetryableFailures={IncludeNonRetryableFailures}, RequeuedTransactionCount={RequeuedTransactionCount}, ResetOutboxRowCount={ResetOutboxRowCount}, ResetStatusRowCount={ResetStatusRowCount}",
                includeNonRetryableFailures,
                result.RequeuedTransactionCount,
                result.ResetOutboxRowCount,
                result.ResetStatusRowCount);

            return result;
        }
    }
}