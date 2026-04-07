namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Read-side repository for the approved transaction to Sage orchestration flow.
    /// Responsible only for deterministic reads and payload deserialization.
    /// </summary>
    public interface ITransactionToSageReadRepository
    {
        /// <summary>
        /// Attempts to deserialize an outbox payload into a strongly typed approved transaction event.
        /// Returns null when the payload is empty or invalid.
        /// </summary>
        TransactionApprovedForSageSubmissionEvent? DeserializeApprovedTransactionEvent(string payloadJson);

        /// <summary>
        /// Loads the full approved transaction read model for Sage submission using the transition guid.
        /// Returns null if the transition or transaction cannot be resolved.
        /// </summary>
        Task<ApprovedTransactionForSageReadModel?> GetApprovedTransactionForSageAsync(
            Guid transactionBatchTransitionGuid,
            CancellationToken cancellationToken = default);
    }
}