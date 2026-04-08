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

        public List<SageInboundPaymentSyncClientResultItem> Items { get; set; } = new();
    }

    public sealed class SageInboundPaymentSyncClientResultItem
    {
        public long ExternalTransactionId { get; set; } = -1;

        public long MatchedTransactionId { get; set; } = -1;

        public int MatchedInvoiceRequestId { get; set; } = -1;

        public int MatchedJobId { get; set; } = -1;

        public string MatchRule { get; set; } = string.Empty;
    }
}