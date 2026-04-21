#nullable enable

namespace Concursus.Common.Shared.Models.Finance
{
    public sealed class TransactionInvoicePreviewGenerateRequest
    {
        public Guid TransactionGuid { get; set; }
        public bool ForceRegenerate { get; set; }
    }

    public enum TransactionInvoiceRenderMode
    {
        Preview = 0,
        Final = 1
    }


    public sealed class TransactionInvoicePreviewGenerateResult
    {
        public Guid TransactionGuid { get; set; }
        public bool IsSuccess { get; set; }
        public string Message { get; set; } = string.Empty;
        public string ReservedInvoiceNumber { get; set; } = string.Empty;
        public string SharePointDriveId { get; set; } = string.Empty;
        public string SharePointItemId { get; set; } = string.Empty;
        public string SharePointWebUrl { get; set; } = string.Empty;
        public string Filename { get; set; } = string.Empty;
        public string MimeType { get; set; } = string.Empty;
        public DateTime? GeneratedDateTimeUtc { get; set; }
        public bool IsCurrent { get; set; }
    }

    public sealed class TransactionInvoicePreviewInfo
    {
        public long Id { get; set; }
        public Guid Guid { get; set; }
        public Guid TransactionGuid { get; set; }
        public string ReservedInvoiceNumber { get; set; } = string.Empty;
        public string SharePointDriveId { get; set; } = string.Empty;
        public string SharePointItemId { get; set; } = string.Empty;
        public string SharePointWebUrl { get; set; } = string.Empty;
        public string Filename { get; set; } = string.Empty;
        public string MimeType { get; set; } = string.Empty;
        public string FileHash { get; set; } = string.Empty;
        public byte[] SourceTransactionRowVersion { get; set; } = Array.Empty<byte>();
        public DateTime GeneratedDateTimeUtc { get; set; }
        public bool IsCurrent { get; set; }
        public bool IsPostedToSage { get; set; }
    }

    public sealed class TransactionInvoicePostingGuardResult
    {
        public Guid TransactionGuid { get; set; }
        public bool HasPreview { get; set; }
        public bool HasReservedInvoiceNumber { get; set; }
        public bool PreviewMatchesCurrentTransaction { get; set; }
        public bool CanPostToSage => HasPreview && HasReservedInvoiceNumber && PreviewMatchesCurrentTransaction;
        public string ReservedInvoiceNumber { get; set; } = string.Empty;
        public string BlockingReason { get; set; } = string.Empty;
    }

    public sealed class TransactionInvoicePrintModel
    {
        public Guid TransactionGuid { get; set; }

        public TransactionInvoiceRenderMode RenderMode { get; set; } = TransactionInvoiceRenderMode.Preview;

        public string CustomerReference { get; set; } = string.Empty;
        public string InvoiceToBlock { get; set; } = string.Empty;
        public DateTime TaxPointDate { get; set; }
        public string PaymentTerms { get; set; } = string.Empty;
        public string CostCentre { get; set; } = string.Empty;
        public string Department { get; set; } = string.Empty;

        // Sage-owned / post-send enrichment
        public string InvoiceNumber { get; set; } = string.Empty;
        public string SalesOrderNumber { get; set; } = string.Empty;

        public string PurchaseOrderNumber { get; set; } = string.Empty;
        public decimal TotalAmountExcludingVat { get; set; }
        public decimal TotalVat { get; set; }
        public decimal TotalAmountDue { get; set; }

        public List<TransactionInvoicePrintLineModel> Lines { get; set; } = new();
    }

    public sealed class TransactionInvoicePrintLineModel
    {
        public string Description { get; set; } = string.Empty;
        public decimal Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal AmountExVat { get; set; }
        public string VatCode { get; set; } = string.Empty;
        public decimal VatAmount { get; set; }
    }
}