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

        // NULL/empty = none, "Paid", "Open" (not terminal), "Receipts" (has a materialised receipt),
        // "CreditNotes" (has a materialised credit note).
        public string PaymentFilter { get; set; } = string.Empty;
        public int PageNumber { get; set; } = 1;
        public int PageSize { get; set; } = 50;
    }

    public sealed class SageInboundDiagnosticsPageResult
    {
        public List<SageInboundDiagnosticsRowModel> Rows { get; } = new();
        public long TotalCount { get; set; }
    }

    // Shares the search filters with SageInboundDiagnosticsGetRequestModel, minus StatusCode/PaymentFilter/paging:
    // the summary always reflects the grand totals per bucket for the search filters, independent of
    // whichever quick-filter status/payment card is currently selected on the main grid.
    public sealed class SageInboundDiagnosticsSummaryRequestModel
    {
        public string SageAccountReference { get; set; } = string.Empty;
        public string SageDocumentNo { get; set; } = string.Empty;
        public string TransactionNumber { get; set; } = string.Empty;
        public bool? OnlyRetryableFailures { get; set; }
        public int? InvoiceRequestId { get; set; }
        public long? TransactionId { get; set; }
        public int? JobId { get; set; }
    }

    public sealed class SageInboundDiagnosticsSummaryModel
    {
        public long TotalCount { get; set; }
        public long SucceededCount { get; set; }
        public long RetryPendingCount { get; set; }
        public long PaidCount { get; set; }
        public long ReceiptsCreatedCount { get; set; }
        public long CreditNotesCreatedCount { get; set; }
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
        public string JobNumber { get; set; } = string.Empty;

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

        public long? LastMatchedExternalTransactionId { get; set; }
        public int? LastMatchedExternalTransactionTypeCode { get; set; }
        public decimal? LastMatchedExternalTransactionAllocatedValue { get; set; }

        public bool HasMaterialisedReceipt =>
            MaterialisedReceiptTransactionGuid.HasValue &&
            MaterialisedReceiptTransactionGuid.Value != Guid.Empty;

        public bool HasMaterialisedAllocation =>
            MaterialisedAllocationGuid.HasValue &&
            MaterialisedAllocationGuid.Value != Guid.Empty;

        // Mirrors SFin.SageInboundReceiptMaterialisation_AutoCorrect's candidate filter.
        // CYB-568: an allocated Invoice (4) is a candidate too - the materialise procedure
        // creates a Receipt from it while no explicit Credit Note/Receipt (1/5) exists.
        public bool CanFixReceipt =>
            !HasMaterialisedReceipt &&
            LastMatchedExternalTransactionId.HasValue &&
            (LastMatchedExternalTransactionTypeCode == 5 ||
             LastMatchedExternalTransactionTypeCode == 1 ||
             LastMatchedExternalTransactionTypeCode == 4) &&
            Math.Abs(LastMatchedExternalTransactionAllocatedValue ?? 0m) > 0m;

        public string InvoiceReference => InvoiceRequestId > 0 ? $"IR-{InvoiceRequestId}" : "-";
        public string TransactionReference => TransactionId > 0 ? $"TRN-{TransactionId}" : "-";
        public string JobReference => !string.IsNullOrWhiteSpace(JobNumber)
            ? JobNumber
            : JobId > 0
                ? $"JOB-{JobId}"
                : "-";
        public string RetryableDisplay => LastErrorIsRetryable == true ? "Yes" : LastErrorIsRetryable == false ? "No" : "-";
        public string EffectiveErrorMessage => !string.IsNullOrWhiteSpace(LastError)
            ? LastError
            : !string.IsNullOrWhiteSpace(LastAttemptErrorMessage)
                ? LastAttemptErrorMessage
                : string.Empty;

        public string DisplayTransactionNumber => string.IsNullOrWhiteSpace(TransactionNumber) ? "-" : TransactionNumber;
        public string DisplayMatchedTransactionNumber => string.IsNullOrWhiteSpace(MatchedTransactionNumber) ? "-" : MatchedTransactionNumber;
        public string DisplayReceiptTransactionNumber => string.IsNullOrWhiteSpace(MaterialisedReceiptTransactionNumber) ? "-" : MaterialisedReceiptTransactionNumber;

        // CYB-555: the materialised transaction is a Credit Note when the
        // matched Sage row is one (type 5). The diagnostics prefer the 1/5 row
        // over the invoice's own row, so a type 4 fallback is a Receipt.
        public string MaterialisedTransactionLabel =>
            LastMatchedExternalTransactionTypeCode == 5 ? "Credit Note" : "Receipt";

        // CYB-555: -1 is a Sage allocation whose counterpart Sage could not
        // resolve. Nothing is created for it, and Fix Receipt must not invent one.
        public bool IsSettledMethodUnknown =>
            !HasMaterialisedReceipt && LastMatchedExternalTransactionTypeCode == -1;
    }
}