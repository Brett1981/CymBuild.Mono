#nullable enable

using System.ComponentModel.DataAnnotations;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Configuration options for the Phase 5 Sage transaction submission worker.
    ///
    /// This worker polls SCore.IntegrationOutbox for TransactionApprovedForSageSubmission
    /// events and invokes ITransactionToSageSubmissionService for each claimed row.
    /// </summary>
    public sealed class SageTransactionSubmissionWorkerOptions
    {
        /// <summary>
        /// Enables or disables the worker itself.
        /// This is separate from Integrations:SageApi:Enabled.
        /// The worker will still also honour the main SageApi Enabled flag.
        /// </summary>
        public bool Enabled { get; set; } = true;

        /// <summary>
        /// Polling interval in seconds when the worker is running normally.
        /// </summary>
        [Range(1, 3600)]
        public int IntervalSeconds { get; set; } = 10;

        /// <summary>
        /// Maximum publish/processing attempts before the worker stops retrying an outbox row.
        /// </summary>
        [Range(1, 100)]
        public int MaxAttempts { get; set; } = 10;

        /// <summary>
        /// Number of minutes after which an abandoned in-progress outbox row
        /// can be reclaimed by a new worker instance.
        /// </summary>
        [Range(1, 1440)]
        public int ClaimTimeoutMinutes { get; set; } = 15;

        /// <summary>
        /// Event type consumed by this worker.
        /// Kept configurable for safety and diagnostics, but should normally remain unchanged.
        /// </summary>
        [Required]
        public string EventType { get; set; } = "TransactionApprovedForSageSubmission";
    }
}