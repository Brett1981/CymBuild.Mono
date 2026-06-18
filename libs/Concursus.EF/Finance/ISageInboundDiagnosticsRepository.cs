using Concursus.Common.Shared.Models.Finance;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.EF.Finance
{
    public interface ISageInboundDiagnosticsRepository
    {
        Task<List<SageInboundDiagnosticsRowModel>> GetAsync(
            SageInboundDiagnosticsGetRequestModel request,
            CancellationToken cancellationToken = default);

        Task<SageInboundReceiptMaterialisationAutoCorrectResult> AutoCorrectReceiptMaterialisationAsync(
            long? externalTransactionId,
            int batchSize,
            bool dryRun,
            CancellationToken cancellationToken = default);

        Task<int> ApplyTransactionReferencesAsync(
            Guid? statusGuid = null,
            long? transactionId = null,
            bool dryRun = true,
            CancellationToken cancellationToken = default);

        Task<bool> SetTransactionSageReferenceIfMissingAsync(
            long transactionId,
            string sageTransactionReference,
            CancellationToken cancellationToken = default);
    }
}