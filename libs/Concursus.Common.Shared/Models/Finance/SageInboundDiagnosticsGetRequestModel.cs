using System;

namespace Concursus.Common.Shared.Models.Finance
{
    public sealed class SageInboundDiagnosticsGetRequestModel
    {
        public string StatusCode { get; set; } = string.Empty;
        public string SageAccountReference { get; set; } = string.Empty;
        public string SageDocumentNo { get; set; } = string.Empty;
        public bool? OnlyRetryableFailures { get; set; }
        public int? InvoiceRequestId { get; set; }
        public long? TransactionId { get; set; }
        public int? JobId { get; set; }
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
        public DateTime? LastAttemptedOnUtc { get; set; }
        public DateTime? LastCompletedOnUtc { get; set; }
        public bool? LastAttemptIsSuccess { get; set; }
        public string LastAttemptErrorMessage { get; set; } = string.Empty;
        public bool? LastAttemptIsRetryableFailure { get; set; }
        public string LastAttemptResponseStatus { get; set; } = string.Empty;
        public string LastAttemptResponseDetail { get; set; } = string.Empty;
        public bool CanRequeue { get; set; }
        public bool CanForceRequeue { get; set; }

        public string InvoiceReference => InvoiceRequestId > 0 ? $"IR-{InvoiceRequestId}" : "-";
        public string TransactionReference => TransactionId > 0 ? $"TRN-{TransactionId}" : "-";
        public string JobReference => JobId > 0 ? $"JOB-{JobId}" : "-";
        public string RetryableDisplay => LastErrorIsRetryable == true ? "Yes" : LastErrorIsRetryable == false ? "No" : "-";
        public string EffectiveErrorMessage => !string.IsNullOrWhiteSpace(LastError)
            ? LastError
            : !string.IsNullOrWhiteSpace(LastAttemptErrorMessage)
                ? LastAttemptErrorMessage
                : string.Empty;
    }
}
