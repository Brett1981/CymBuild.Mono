using System;

namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Result of attempting to claim exclusive processing rights for a transaction Sage submission.
    /// </summary>
    public sealed class TransactionToSageIdempotencyClaimResult
    {
        /// <summary>
        /// Transaction guid the claim attempt relates to.
        /// </summary>
        public Guid TransactionGuid { get; set; }

        /// <summary>
        /// Finance approval transition guid used for correlation.
        /// </summary>
        public Guid TransitionGuid { get; set; }

        /// <summary>
        /// True when this process successfully claimed the transaction for submission.
        /// </summary>
        public bool ClaimAcquired { get; set; }

        /// <summary>
        /// True when the transaction had already been successfully processed.
        /// </summary>
        public bool AlreadyProcessed { get; set; }

        /// <summary>
        /// True when another process appears to have an active in-flight claim.
        /// </summary>
        public bool InProgressElsewhere { get; set; }


        public bool StaleClaimReclaimed { get; set; }

        public string StatusCode { get; set; } = string.Empty;

        public DateTime? PreviousClaimedOnUtc { get; set; }
        /// <summary>
        /// Optional returned Sage order identifier/reference where already processed.
        /// </summary>
        public string SageOrderId { get; set; } = string.Empty;

        /// <summary>
        /// Optional returned Sage order number/reference where already processed.
        /// </summary>
        public string SageOrderNumber { get; set; } = string.Empty;

        /// <summary>
        /// Human-readable message describing the claim result.
        /// </summary>
        public string Message { get; set; } = string.Empty;

        /// <summary>
        /// UTC time when the claim result was produced.
        /// </summary>
        public DateTime EvaluatedOnUtc { get; set; } = DateTime.UtcNow;
    }
}