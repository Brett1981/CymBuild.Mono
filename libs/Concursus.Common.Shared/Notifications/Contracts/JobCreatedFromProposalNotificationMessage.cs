using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace Concursus.Common.Shared.Notifications.Contracts
{
    /// <summary>
    /// CYB-36
    /// Kafka notification published when a Job is created from a Quote proposal.
    ///
    /// Trigger source:
    /// SCore.IntegrationOutbox (EventType = JobCreatedFromProposal)
    ///
    /// Recipients are embedded directly in PayloadJson from SQL trigger.
    /// </summary>
    public sealed class JobCreatedFromProposalNotificationMessage
    {
        /// <summary>
        /// Logical message source used by downstream systems.
        /// Example: cymbuild-job-created-from-proposal
        /// </summary>
        public required string Source { get; init; }

        /// <summary>
        /// Email recipients resolved in SQL trigger payload.
        /// </summary>
        public List<string> Recipients { get; init; } = [];

        /// <summary>
        /// Main event payload.
        /// </summary>
        public required JobCreatedFromProposalNotificationData Data { get; init; }

        /// <summary>
        /// Kafka publish timestamp.
        /// </summary>
        public DateTime TimestampUtc { get; init; } = DateTime.UtcNow;

        /// <summary>
        /// Backwards-compatible key/value links collection.
        /// </summary>
        public List<Links> Links { get; set; } = [];
    }

    /// <summary>
    /// Main event data payload.
    /// </summary>
    public sealed class JobCreatedFromProposalNotificationData
    {
        public required Guid EventGuid { get; init; }
        public required string EventType { get; init; }
        public required DateTime OccurredOnUtc { get; init; }

        public required Guid JobGuid { get; init; }
        public string? JobNumber { get; init; }
        public DateTime? JobCreatedOnUtc { get; init; }

        public Guid? QuoteGuid { get; init; }
        public string? QuoteReference { get; init; }

        public string? ClientName { get; init; }
        public string? ProjectDescription { get; init; }

        // NEW - stable alias for templating
        public string? Description { get; init; }

        public JobCreatedFromProposalPerson? Actor { get; init; }
        public JobCreatedFromProposalPerson? Drafter { get; init; }

        [JsonPropertyName("links")]
        public JobCreatedFromProposalLinkSet Links { get; init; } = new();

        [JsonPropertyName("linksKv")]
        public List<Links> LinksKv { get; init; } = [];
    }

    /// <summary>
    /// Actor or Drafter information.
    /// </summary>
    public sealed class JobCreatedFromProposalPerson
    {
        public int? IdentityId { get; init; }

        public string? FullName { get; init; }

        public string? EmailAddress { get; init; }
    }

    /// <summary>
    /// Strongly typed link structure for templates.
    /// </summary>
    public sealed class JobCreatedFromProposalLinkSet
    {
        [JsonPropertyName("jobUrl")]
        public string? JobUrl { get; init; }

        [JsonPropertyName("jobRecordStatusUrl")]
        public string? JobRecordStatusUrl { get; init; }

        [JsonPropertyName("quoteUrl")]
        public string? QuoteUrl { get; init; }
    }
}