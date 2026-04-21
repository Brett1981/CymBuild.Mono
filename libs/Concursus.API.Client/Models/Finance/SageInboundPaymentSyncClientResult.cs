namespace Concursus.API.Client.Models.Finance
{
    public sealed class SageInboundPaymentSyncClientResult
    {
        public Guid CymBuildDocumentGuid { get; set; }

        public bool IsSuccess { get; set; }

        public bool IsRetryableFailure { get; set; }

        public string Message { get; set; } = string.Empty;

        public int ExternalTransactionCount { get; set; }

        public int ExternalAllocationCount { get; set; }

        public int ReconciledInvoiceCount { get; set; }

        public int ReconciledAllocationCount { get; set; }

        public int UpdatedInvoiceRequestCount { get; set; }

        public int FullyPaidCount { get; set; }

        public int PartiallyPaidCount { get; set; }

        public int UnpaidCount { get; set; }

        public bool ShouldContinuePolling { get; set; }

        public List<SageInboundPaymentSyncClientResultItem> Items { get; set; } = new();
    }

    public sealed class SageInboundPaymentSyncClientResultItem
    {
        public long ExternalTransactionId { get; set; } = -1;

        public long MatchedTransactionId { get; set; } = -1;

        public int MatchedInvoiceRequestId { get; set; } = -1;

        public int MatchedJobId { get; set; } = -1;

        public string MatchRule { get; set; } = string.Empty;

        public string SageTransactionReference { get; set; } = string.Empty;

        public string SageDocumentNo { get; set; } = string.Empty;

        public int SageTransactionTypeCode { get; set; } = -1;

        public decimal GrossAmount { get; set; }

        public decimal AllocatedValue { get; set; }

        public decimal OutstandingAmount { get; set; }

        public decimal DocumentDiscountedValue { get; set; }

        public bool IsPaid { get; set; }

        public bool IsFullyPaid { get; set; }

        public string PaymentStateCode { get; set; } = string.Empty;

        public DateTime? TransactionDateUtc { get; set; }

        public DateTime? LastSeenOnUtc { get; set; }
    }
}