using System;
using System.Collections.Generic;
using System.Text;

namespace Concursus.Common.Shared.Notifications.Contracts
{
    /// <summary>
    /// Payload contract for Job closure decision notifications.
    /// Stored in outbox now; published to Kafka later by a worker.
    /// </summary>
    public sealed class JobClosureDecisionEvent
    {
        public required Guid JobGuid { get; init; }

        // Decision metadata
        public required int DecisionCode { get; init; } // 1=Approve, 2=Reject
        public required string Decision { get; init; }  // "Approve" | "Reject"
        public required string Comment { get; init; }

        // Actor
        public required Guid ActorUserGuid { get; init; }
        public required int ActorUserId { get; init; }
        public required DateTime DecisionDateTimeUtc { get; init; }

        // Targeting (group-based notifications)
        public required string TargetGroupCode { get; init; }
        public Guid? TargetUserGroupGuid { get; init; }

        // Future-friendly optional enrichments (safe additions)
        public string? JobNumber { get; init; }
    }
}
