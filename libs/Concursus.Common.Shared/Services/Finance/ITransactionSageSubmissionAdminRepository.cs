using Concursus.Common.Shared.Models.Finance;
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.Common.Shared.Services.Finance
{
    public interface ITransactionSageSubmissionAdminRepository
    {
        Task<TransactionSageSubmissionRequeueResult> RequeueAsync(
            IReadOnlyCollection<Guid> transactionGuids,
            CancellationToken cancellationToken = default);
    }
}