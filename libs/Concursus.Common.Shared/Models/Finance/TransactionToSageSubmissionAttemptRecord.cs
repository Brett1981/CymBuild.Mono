using System;

namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Append-only record of a transaction submission attempt to the new Sage REST wrapper.
    /// </summary>
    public sealed class TransactionToSageSubmissionAttemptRecord
    {
        public Guid AttemptGuid { get; set; }
        public Guid TransactionGuid { get; set; }
        public Guid TransitionGuid { get; set; }
        public string OperationName { get; set; } = string.Empty;
        public DateTime AttemptedOnUtc { get; set; }
        public DateTime? CompletedOnUtc { get; set; }
        public bool IsSuccess { get; set; }
        public bool IsRetryableFailure { get; set; }
        public string SageOrderId { get; set; } = string.Empty;
        public string SageOrderNumber { get; set; } = string.Empty;
        public string ResponseStatus { get; set; } = string.Empty;
        public string ResponseDetail { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public string RequestPayloadJson { get; set; } = string.Empty;
        public string ResponsePayloadJson { get; set; } = string.Empty;
    }
}