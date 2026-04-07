using System;
using System.Text.Json.Serialization;

namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Durable event payload raised when a finance transaction is approved for Sage submission.
    /// This event is emitted after SFin.Transactions.Batched transitions from 1 to 0.
    /// </summary>
    public sealed class TransactionApprovedForSageSubmissionEvent
    {
        /// <summary>
        /// Unique identifier for the outbox/integration event.
        /// JSON contract: eventGuid
        /// </summary>
        [JsonPropertyName("eventGuid")]
        public Guid EventGuid { get; set; }

        /// <summary>
        /// Event type name written into the integration outbox.
        /// JSON contract: eventType
        /// </summary>
        [JsonPropertyName("eventType")]
        public string EventType { get; set; } = string.Empty;

        /// <summary>
        /// UTC timestamp for when the business event occurred.
        /// JSON contract: occurredOnUtc
        /// </summary>
        [JsonPropertyName("occurredOnUtc")]
        public DateTime OccurredOnUtc { get; set; }

        /// <summary>
        /// Guid of the append-only finance approval transition row.
        /// JSON contract: transitionGuid
        /// </summary>
        [JsonPropertyName("transitionGuid")]
        public Guid TransitionGuid { get; set; }

        /// <summary>
        /// Numeric identifier of the append-only finance approval transition row.
        /// JSON contract: transitionId
        /// </summary>
        [JsonPropertyName("transitionId")]
        public long TransitionId { get; set; }

        /// <summary>
        /// Guid of the finance transaction being approved for submission.
        /// JSON contract: transactionGuid
        /// </summary>
        [JsonPropertyName("transactionGuid")]
        public Guid TransactionGuid { get; set; }

        /// <summary>
        /// Database identifier of the finance transaction being approved for submission.
        /// JSON contract: transactionId
        /// </summary>
        [JsonPropertyName("transactionId")]
        public long TransactionId { get; set; }

        /// <summary>
        /// Human-readable finance transaction number/reference.
        /// JSON contract: transactionNumber
        /// </summary>
        [JsonPropertyName("transactionNumber")]
        public string TransactionNumber { get; set; } = string.Empty;

        /// <summary>
        /// Optional related Job identifier.
        /// JSON contract: jobId
        /// </summary>
        [JsonPropertyName("jobId")]
        public int? JobId { get; set; }

        /// <summary>
        /// Optional related Account identifier.
        /// JSON contract: accountId
        /// </summary>
        [JsonPropertyName("accountId")]
        public int? AccountId { get; set; }

        /// <summary>
        /// Related organisational unit identifier.
        /// JSON contract: organisationalUnitId
        /// </summary>
        [JsonPropertyName("organisationalUnitId")]
        public int? OrganisationalUnitId { get; set; }

        /// <summary>
        /// Identity id of the user who caused the approval transition where available.
        /// JSON contract: actorIdentityId
        /// </summary>
        [JsonPropertyName("actorIdentityId")]
        public int? ActorIdentityId { get; set; }

        /// <summary>
        /// Optional surveyor identity id associated to the transaction.
        /// JSON contract: surveyorIdentityId
        /// </summary>
        [JsonPropertyName("surveyorIdentityId")]
        public int? SurveyorIdentityId { get; set; }

        /// <summary>
        /// Returns true when the event contains the minimum identifiers required to process the transaction.
        /// </summary>
        public bool IsValidForProcessing()
        {
            return EventGuid != Guid.Empty
                   && TransitionGuid != Guid.Empty
                   && TransactionGuid != Guid.Empty
                   && TransitionId > 0
                   && TransactionId > 0
                   && !string.IsNullOrWhiteSpace(EventType);
        }
    }
}