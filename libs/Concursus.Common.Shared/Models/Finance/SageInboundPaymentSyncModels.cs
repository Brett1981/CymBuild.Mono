#nullable enable

using System;
using System.Collections.Generic;

namespace Concursus.Common.Shared.Models.Finance
{
    public sealed class SageInboundSyncTarget
    {
        public Guid CymBuildDocumentGuid { get; set; }
        public int CymBuildEntityTypeId { get; set; } = -1;
        public long CymBuildDocumentId { get; set; } = -1;
        public int InvoiceRequestId { get; set; } = -1;
        public long TransactionId { get; set; } = -1;
        public int JobId { get; set; } = -1;
        public string SageDataset { get; set; } = string.Empty;
        public string SageAccountReference { get; set; } = string.Empty;
        public string SageDocumentNo { get; set; } = string.Empty;
    }

    public sealed class SageCustomerTransactionRecord
    {
        public string TransactionReference { get; set; } = string.Empty;
        public string AccountReference { get; set; } = string.Empty;
        public string SecondReference { get; set; } = string.Empty;
        public int SysTraderTranType { get; set; } = -1;
        public string DocumentNo { get; set; } = string.Empty;
        public DateTime? TransactionDateUtc { get; set; }
        public decimal NetAmount { get; set; }
        public decimal TaxAmount { get; set; }
        public decimal GrossAmount { get; set; }
        public decimal OutstandingAmount { get; set; }
        public decimal AllocatedValue { get; set; }
        public decimal DocumentDiscountedValue { get; set; }
        public bool IsPaid { get; set; }
        public bool IsFullyPaid { get; set; }
        public string RawPayloadJson { get; set; } = string.Empty;
        public string SourceHash { get; set; } = string.Empty;
    }

    public sealed class SageCustomerAllocationRecord
    {
        public string SourceDocumentNo { get; set; } = string.Empty;
        public string SourceTransactionReference { get; set; } = string.Empty;
        public string TargetDocumentNo { get; set; } = string.Empty;
        public string TargetTransactionReference { get; set; } = string.Empty;
        public decimal AllocatedAmount { get; set; }
        public DateTime? AllocationDateUtc { get; set; }
        public string RawPayloadJson { get; set; } = string.Empty;
        public string SourceHash { get; set; } = string.Empty;
    }

    public static class SageAggregatePaymentStateCodes
    {
        public const string Unknown = "Unknown";
        public const string Unpaid = "Unpaid";
        public const string PartiallyPaid = "PartiallyPaid";
        public const string Paid = "Paid";
        public const string OverAllocated = "OverAllocated";
    }

    public sealed class SageInboundPaymentSyncRequest
    {
        public Guid CymBuildDocumentGuid { get; set; }
        public bool Force { get; set; }
    }

    public sealed class SageInboundPaymentSyncResult
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
        public List<SageInboundPaymentSyncResultItem> Items { get; set; } = new();
    }

    public sealed class SageInboundPaymentSyncResultItem
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
        public string PaymentStateCode { get; set; } = SageAggregatePaymentStateCodes.Unknown;
        public DateTime? TransactionDateUtc { get; set; }
        public DateTime? LastSeenOnUtc { get; set; }
    }

    public sealed class SageInboundStatusEnsureResult
    {
        public Guid Guid { get; set; }
        public bool ExistsAlready { get; set; }
    }

    public sealed class SageInboundClaimResult
    {
        public bool ClaimSucceeded { get; set; }
        public long Id { get; set; } = -1;
        public Guid Guid { get; set; }
        public int CymBuildEntityTypeId { get; set; } = -1;
        public Guid CymBuildDocumentGuid { get; set; }
        public long CymBuildDocumentId { get; set; } = -1;
        public int InvoiceRequestId { get; set; } = -1;
        public long TransactionId { get; set; } = -1;
        public int JobId { get; set; } = -1;
        public string SageDataset { get; set; } = string.Empty;
        public string SageAccountReference { get; set; } = string.Empty;
        public string SageDocumentNo { get; set; } = string.Empty;
        public string StatusCode { get; set; } = string.Empty;
        public bool IsInProgress { get; set; }
        public DateTime? InProgressClaimedOnUtc { get; set; }
    }

    public sealed class SageExternalTransactionUpsertRequest
    {
        public string SageDataset { get; set; } = string.Empty;
        public string SageAccountReference { get; set; } = string.Empty;
        public string SageDocumentNo { get; set; } = string.Empty;
        public string SageTransactionReference { get; set; } = string.Empty;
        public string SecondReference { get; set; } = string.Empty;
        public int SageTransactionTypeCode { get; set; } = -1;
        public DateTime? TransactionDateUtc { get; set; }
        public decimal NetAmount { get; set; }
        public decimal TaxAmount { get; set; }
        public decimal GrossAmount { get; set; }
        public decimal OutstandingAmount { get; set; }
        public decimal AllocatedValue { get; set; }
        public decimal DocumentDiscountedValue { get; set; }
        public bool IsPaid { get; set; }
        public bool IsFullyPaid { get; set; }
        public string PaymentStateCode { get; set; } = SageAggregatePaymentStateCodes.Unknown;
        public long MatchedTransactionId { get; set; } = -1;
        public int MatchedInvoiceRequestId { get; set; } = -1;
        public int MatchedJobId { get; set; } = -1;
        public string SourceHash { get; set; } = string.Empty;
        public string RawPayloadJson { get; set; } = string.Empty;
    }

    public sealed class SageExternalAllocationUpsertRequest
    {
        public long SourceExternalTransactionId { get; set; } = -1;
        public long TargetExternalTransactionId { get; set; } = -1;
        public decimal AllocatedAmount { get; set; }
        public DateTime? AllocationDateUtc { get; set; }
        public long MatchedSourceTransactionId { get; set; } = -1;
        public long MatchedTargetTransactionId { get; set; } = -1;
        public string SourceHash { get; set; } = string.Empty;
        public string RawPayloadJson { get; set; } = string.Empty;
    }

    public sealed class SageReconcileInvoiceResult
    {
        public long ExternalTransactionId { get; set; } = -1;
        public bool IsMatched { get; set; }
        public long MatchedTransactionId { get; set; } = -1;
        public int MatchedInvoiceRequestId { get; set; } = -1;
        public int MatchedJobId { get; set; } = -1;
        public string MatchRule { get; set; } = string.Empty;
    }

    public sealed class SageReconcileAllocationResult
    {
        public long ExternalAllocationId { get; set; } = -1;
        public bool IsFullyMatched { get; set; }
        public long MatchedSourceTransactionId { get; set; } = -1;
        public long MatchedTargetTransactionId { get; set; } = -1;
    }

    public sealed class SageAggregatePaymentStateResult
    {
        public long ExternalTransactionId { get; set; } = -1;
        public string PaymentStateCode { get; set; } = SageAggregatePaymentStateCodes.Unknown;
        public decimal GrossAmount { get; set; }
        public decimal AllocatedValue { get; set; }
        public decimal OutstandingAmount { get; set; }
        public decimal DocumentDiscountedValue { get; set; }
        public bool IsPaid { get; set; }
        public bool IsFullyPaid { get; set; }
    }

    public sealed class SageInboundPaymentWorklistItem
    {
        public long Id { get; set; } = -1;
        public Guid Guid { get; set; }
        public int CymBuildEntityTypeId { get; set; } = -1;
        public Guid CymBuildDocumentGuid { get; set; }
        public long CymBuildDocumentId { get; set; } = -1;
        public int InvoiceRequestId { get; set; } = -1;
        public long TransactionId { get; set; } = -1;
        public int JobId { get; set; } = -1;
        public string SageDataset { get; set; } = string.Empty;
        public string SageAccountReference { get; set; } = string.Empty;
        public string SageDocumentNo { get; set; } = string.Empty;
        public string StatusCode { get; set; } = string.Empty;

        // Keep these for backward compatibility with the existing EF repository / worker code.
        public bool IsInProgress { get; set; }
        public DateTime? InProgressClaimedOnUtc { get; set; }
        public DateTime? LastSucceededOnUtc { get; set; }
        public DateTime? LastFailedOnUtc { get; set; }
        public string LastError { get; set; } = string.Empty;
        public bool? LastErrorIsRetryable { get; set; }
    }

    public sealed class SageInboundPaymentSyncEnqueueRequest
    {
        public Guid CymBuildDocumentGuid { get; set; }
        public bool ForceRequeue { get; set; }
    }

    public sealed class SageInboundPaymentSyncEnqueueResult
    {
        public Guid CymBuildDocumentGuid { get; set; }
        public bool IsSuccess { get; set; }
        public string Message { get; set; } = string.Empty;
    }
}