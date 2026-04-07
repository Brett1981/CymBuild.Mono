using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace Concursus.Common.Shared.Notifications.Contracts
{
    public sealed class WorkflowStatusNotificationMessage
    {
        public required string Source { get; init; }
        public List<string> Recipients { get; init; } = [];
        public required WorkflowStatusNotificationData Data { get; init; }
        public DateTime TimestampUtc { get; init; } = DateTime.UtcNow;
        public List<Links> Links { get; set; } = [];
    }

    public sealed class Links
    {
        public string? Key { get; set; }
        public string? Value { get; set; }
    }

    public sealed class WorkflowStatusNotificationLinkSet
    {
        [JsonPropertyName("recordUrl")]
        public string? RecordUrl { get; init; }

        [JsonPropertyName("recordStatusUrl")]
        public string? RecordStatusUrl { get; init; }
    }

    public sealed class WorkflowStatusNotificationTargetGroup
    {
        public int GroupId { get; init; }
        public string? GroupCode { get; init; }
        public string? GroupName { get; init; }
        public bool CanAction { get; init; }
    }

    public sealed class WorkflowStatusNotificationActor
    {
        public int? IdentityId { get; init; }
        public Guid? IdentityGuid { get; init; }
        public string? FullName { get; init; }
        public string? EmailAddress { get; init; }
    }

    public sealed class WorkflowStatusNotificationData
    {
        public required Guid RecordGuid { get; init; }
        public required int EntityTypeId { get; init; }
        public required string EntityTypeName { get; init; }

        public required int WorkflowId { get; init; }
        public string? WorkflowName { get; init; }

        public required Guid WorkflowStatusGuid { get; init; }
        public required string WorkflowStatusName { get; init; }
        public int? WorkflowStatusId { get; init; }

        public required Guid TransitionGuid { get; init; }
        public int? TransitionId { get; init; }
        public required DateTime TransitionUtc { get; init; }

        public int? OldWorkflowStatusId { get; init; }
        public Guid? OldWorkflowStatusGuid { get; init; }
        public string? OldWorkflowStatusName { get; init; }

        public string? Comment { get; init; }

        public required int ActorUserId { get; init; }
        public WorkflowStatusNotificationActor? Actor { get; init; }
        public int? SurveyorUserId { get; init; }
        public WorkflowStatusNotificationActor? Surveyor { get; init; }

        public string? TargetGroupIdsCsv { get; init; }
        public List<WorkflowStatusNotificationTargetGroup> TargetGroups { get; init; } = [];

        public int? OrganisationalUnitId { get; init; }
        public string? OrganisationalUnitName { get; init; }

        public string? DisplayRef { get; init; }
        public string? DisplayTitle { get; init; }
        public string? DisplayOrganisationName { get; init; }
        public string? DisplayProjectName { get; init; }
        public string? DisplayClientName { get; init; }
        public string? DisplayAgentName { get; init; }
        public string? DisplayAddress { get; init; }

        /*
            Added for CYB-4 – Bid Team enquiry notification.
            Represents the enquiry quoting deadline (SSop.Enquiries.QuotingDeadlineDate).
        */
        public DateTime? DueDateUtc { get; init; }

        // Optional formatted version for email templates
        public string? DueDateDisplay { get; init; }

        // Existing extension field
        public string? Description { get; init; }

        [JsonPropertyName("links")]
        public WorkflowStatusNotificationLinkSet? Links { get; init; }

        [JsonPropertyName("linksKv")]
        public List<Links> LinksKv { get; init; } = [];
    }
}