#nullable enable

using Concursus;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Repository abstraction for polling and updating outbox rows that represent
    /// approved finance transactions awaiting Sage submission.
    /// </summary>
    public interface ITransactionApprovedOutboxRepository
    {
        /// <summary>
        /// Attempts to claim the next eligible TransactionApprovedForSageSubmission outbox row.
        /// Returns null when no eligible rows are available.
        /// </summary>
        Task<TransactionApprovedOutboxItem?> TryClaimNextAsync(
            string eventType,
            string publishingToken,
            int maxAttempts,
            int claimTimeoutMinutes,
            CancellationToken cancellationToken = default);

        /// <summary>
        /// Marks an outbox row as successfully handled by the Sage submission worker.
        /// This prevents it from being retried again.
        /// </summary>
        Task MarkSucceededAsync(
            long outboxId,
            string publishingToken,
            string? detail,
            CancellationToken cancellationToken = default);

        /// <summary>
        /// Marks an outbox row as failed.
        /// For retryable failures the row remains pending.
        /// For non-retryable failures the row is completed to stop endless retries.
        /// </summary>
        Task MarkFailedAsync(
            long outboxId,
            string publishingToken,
            string error,
            bool isRetryable,
            CancellationToken cancellationToken = default);
    }

    /// <summary>
    /// Claimed outbox item returned to the worker.
    /// </summary>
    public sealed class TransactionApprovedOutboxItem
    {
        /// <summary>
        /// Database identifier of the claimed outbox row.
        /// </summary>
        public long OutboxId { get; set; }

        /// <summary>
        /// Event type of the claimed row.
        /// </summary>
        public string EventType { get; set; } = string.Empty;

        /// <summary>
        /// The raw payload JSON that will be passed into the submission service.
        /// </summary>
        public string PayloadJson { get; set; } = string.Empty;

        /// <summary>
        /// Number of publish/processing attempts already recorded for this row.
        /// </summary>
        public int PublishAttempts { get; set; }

        /// <summary>
        /// Timestamp when this outbox row was created.
        /// </summary>
        public DateTime CreatedOnUtc { get; set; }
    }
}