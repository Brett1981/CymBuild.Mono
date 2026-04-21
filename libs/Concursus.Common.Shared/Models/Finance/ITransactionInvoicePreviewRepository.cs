#nullable enable

namespace Concursus.Common.Shared.Models.Finance
{
    public interface ITransactionInvoicePreviewRepository
    {
        Task<string> ReserveInvoiceNumberAsync(Guid transactionGuid, CancellationToken cancellationToken = default);

        Task<TransactionInvoicePreviewInfo?> GetCurrentAsync(
            Guid transactionGuid,
            CancellationToken cancellationToken = default);

        Task InsertPreviewAsync(
            Guid transactionGuid,
            Guid mergeDocumentGuid,
            string reservedInvoiceNumber,
            string sharePointDriveId,
            string sharePointItemId,
            string sharePointWebUrl,
            string filename,
            string mimeType,
            string fileHash,
            int generatedByUserId,
            CancellationToken cancellationToken = default);

        Task<TransactionInvoicePostingGuardResult> GetPostingGuardAsync(
            Guid transactionGuid,
            CancellationToken cancellationToken = default);

        Task MarkPostedToSageAsync(
            Guid transactionGuid,
            CancellationToken cancellationToken = default);

        Task<TransactionInvoicePrintModel?> GetInvoicePrintModelAsync(
            Guid transactionGuid,
            TransactionInvoiceRenderMode renderMode,
            CancellationToken cancellationToken = default);

        Task<TransactionInvoicePreviewJobContext?> GetJobContextAsync(
            Guid transactionGuid,
            CancellationToken cancellationToken = default);
    }

    public sealed class TransactionInvoicePreviewJobContext
    {
        public Guid TransactionGuid { get; set; }
        public int JobId { get; set; }
        public Guid JobGuid { get; set; }
    }
}