using Concursus.Common.Shared.Models.Finance;
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.API.Services.Finance
{
    public interface ITransactionSageSubmissionAdminService
    {
        Task<TransactionSageSubmissionRequeueResult> RequeueAsync(
            IReadOnlyCollection<Guid> transactionGuids,
            CancellationToken cancellationToken = default);
    }

}