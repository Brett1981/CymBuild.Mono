using System;

namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Current idempotency status for a transaction Sage submission operation.
    /// </summary>
    public sealed class TransactionToSageIdempotencyStatus
    {
        /// <summary>
        /// Transaction guid being evaluated.
        /// </summary>
        public Guid TransactionGuid { get; set; }

        /// <summary>
        /// True when the transaction has already been successfully submitted.
        /// </summary>
        public bool IsAlreadyProcessed { get; set; }

        /// <summary>
        /// True when another process currently appears to hold an active in-flight claim.
        /// </summary>
        public bool IsInProgress { get; set; }

        /// <summary>
        /// Optional Sage order identifier/reference from a previous successful submission.
        /// </summary>
        public string SageOrderId { get; set; } = string.Empty;

        /// <summary>
        /// Optional Sage order number/reference from a previous successful submission.
        /// </summary>
        public string SageOrderNumber { get; set; } = string.Empty;

        /// <summary>
        /// UTC timestamp of the most recent successful submission.
        /// </summary>
        public DateTime? LastSucceededOnUtc { get; set; }

        /// <summary>
        /// UTC timestamp of the most recent failed submission.
        /// </summary>
        public DateTime? LastFailedOnUtc { get; set; }

        /// <summary>
        /// Last known error message where available.
        /// </summary>
        public string LastError { get; set; } = string.Empty;
    }
}