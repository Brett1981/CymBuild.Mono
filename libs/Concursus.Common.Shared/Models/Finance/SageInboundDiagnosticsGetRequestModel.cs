using System;

namespace Concursus.Common.Shared.Models.Finance
{
    public sealed class SageInboundDiagnosticsGetRequestModel
    {
        public string StatusCode { get; set; } = string.Empty;
        public string SageAccountReference { get; set; } = string.Empty;
        public string SageDocumentNo { get; set; } = string.Empty;
        public string TransactionNumber { get; set; } = string.Empty;
        public bool? OnlyRetryableFailures { get; set; }
        public int? InvoiceRequestId { get; set; }
        public long? TransactionId { get; set; }
        public int? JobId { get; set; }
    }

    public sealed class SageInboundReceiptMaterialisationAutoCorrectResult
    {
        public int ProcessedCount { get; set; }
        public int CorrectedCount { get; set; }
        public int SkippedCount { get; set; }
        public int FailedCount { get; set; }
        public List<SageInboundReceiptMaterialisationAutoCorrectResultItem> Items { get; } = new();
    }

    public sealed class SageInboundReceiptMaterialisationAutoCorrectResultItem
    {
        public long ExternalTransactionId { get; set; }
        public string Outcome { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public long MatchedTransactionId { get; set; }
        public long MaterialisedReceiptTransactionId { get; set; }
        public long MaterialisedAllocationId { get; set; }
    }

    public sealed class SageInboundDiagnosticsRowModel
    {
        public long Id { get; set; }
        public Guid Guid { get; set; }
        public int CymBuildEntityTypeId { get; set; }
        public Guid CymBuildDocumentGuid { get; set; }
        public long CymBuildDocumentId { get; set; }
        public int InvoiceRequestId { get; set; }
        public long TransactionId { get; set; }
        public int JobId { get; set; }

        public string SageDataset { get; set; } = string.Empty;
        public string SageAccountReference { get; set; } = string.Empty;
        public string SageDocumentNo { get; set; } = string.Empty;
        public string LastOperationName { get; set; } = string.Empty;
        public string StatusCode { get; set; } = string.Empty;
        public bool IsInProgress { get; set; }
        public DateTime? InProgressClaimedOnUtc { get; set; }
        public DateTime? LastSucceededOnUtc { get; set; }
        public DateTime? LastFailedOnUtc { get; set; }
        public string LastError { get; set; } = string.Empty;
        public bool? LastErrorIsRetryable { get; set; }
        public DateTime? LastSourceWatermarkUtc { get; set; }
        public DateTime UpdatedDateTimeUtc { get; set; }

        public decimal LastGrossAmount { get; set; }
        public decimal LastAllocatedValue { get; set; }
        public decimal LastOutstandingAmount { get; set; }
        public decimal LastDocumentDiscountedValue { get; set; }
        public bool LastIsPaid { get; set; }
        public bool LastIsFullyPaid { get; set; }
        public string LastPaymentStateCode { get; set; } = string.Empty;
        public DateTime? LastTransactionDate { get; set; }
        public string LastSageTransactionReference { get; set; } = string.Empty;
        public string LastSecondReference { get; set; } = string.Empty;
        public int LastSageTransactionTypeCode { get; set; } = -1;
        public DateTime? NextPollDueOnUtc { get; set; }
        public int PollAttemptCount { get; set; }
        public bool IsTerminalState { get; set; }

        public DateTime? LastAttemptedOnUtc { get; set; }
        public DateTime? LastCompletedOnUtc { get; set; }
        public bool? LastAttemptIsSuccess { get; set; }
        public string LastAttemptErrorMessage { get; set; } = string.Empty;
        public bool? LastAttemptIsRetryableFailure { get; set; }
        public string LastAttemptResponseStatus { get; set; } = string.Empty;
        public string LastAttemptResponseDetail { get; set; } = string.Empty;
        public bool CanRequeue { get; set; }
        public bool CanForceRequeue { get; set; }

        public Guid? TransactionGuid { get; set; }
        public string TransactionNumber { get; set; } = string.Empty;
        public bool? TransactionIsBatched { get; set; }

        public Guid? MatchedTransactionGuid { get; set; }
        public string MatchedTransactionNumber { get; set; } = string.Empty;

        public string TransactionSageTransactionReference { get; set; } = string.Empty;
        public string MatchedTransactionSageTransactionReference { get; set; } = string.Empty;

        public Guid? MaterialisedReceiptTransactionGuid { get; set; }
        public string MaterialisedReceiptTransactionNumber { get; set; } = string.Empty;

        public Guid? MaterialisedAllocationGuid { get; set; }
        public long? MaterialisedAllocationId { get; set; }

        public bool HasMaterialisedReceipt =>
            MaterialisedReceiptTransactionGuid.HasValue &&
            MaterialisedReceiptTransactionGuid.Value != Guid.Empty;

        public bool HasMaterialisedAllocation =>
            MaterialisedAllocationGuid.HasValue &&
            MaterialisedAllocationGuid.Value != Guid.Empty;

        public string InvoiceReference => InvoiceRequestId > 0 ? $"IR-{InvoiceRequestId}" : "-";
        public string TransactionReference => TransactionId > 0 ? $"TRN-{TransactionId}" : "-";
        public string JobReference => JobId > 0 ? $"JOB-{JobId}" : "-";
        public string RetryableDisplay => LastErrorIsRetryable == true ? "Yes" : LastErrorIsRetryable == false ? "No" : "-";
        public string EffectiveErrorMessage => !string.IsNullOrWhiteSpace(LastError)
            ? LastError
            : !string.IsNullOrWhiteSpace(LastAttemptErrorMessage)
                ? LastAttemptErrorMessage
                : string.Empty;

        public string DisplayTransactionNumber => string.IsNullOrWhiteSpace(TransactionNumber) ? "-" : TransactionNumber;
        public string DisplayMatchedTransactionNumber => string.IsNullOrWhiteSpace(MatchedTransactionNumber) ? "-" : MatchedTransactionNumber;
        public string DisplayReceiptTransactionNumber => string.IsNullOrWhiteSpace(MaterialisedReceiptTransactionNumber) ? "-" : MaterialisedReceiptTransactionNumber;
    }
}