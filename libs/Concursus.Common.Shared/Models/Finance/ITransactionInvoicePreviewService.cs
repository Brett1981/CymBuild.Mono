#nullable enable

namespace Concursus.Common.Shared.Models.Finance
{
    public interface ITransactionInvoicePreviewService
    {
        Task<TransactionInvoicePreviewGenerateResult> GenerateAsync(
            TransactionInvoicePreviewGenerateRequest request,
            int generatedByUserId,
            CancellationToken cancellationToken = default);

        Task<TransactionInvoicePreviewInfo?> GetCurrentAsync(
            Guid transactionGuid,
            CancellationToken cancellationToken = default);

        Task<TransactionInvoicePostingGuardResult> GetPostingGuardAsync(
            Guid transactionGuid,
            CancellationToken cancellationToken = default);

        Task<TransactionInvoicePrintModel?> GetInvoicePrintModelAsync(
            Guid transactionGuid,
            TransactionInvoiceRenderMode renderMode,
            CancellationToken cancellationToken = default);
    }
}