using Concursus.Common.Shared.Notifications.Contracts;

namespace Concursus.Common.Shared.Notifications.Contracts;

public sealed class JobClosureDecisionNotificationMessage
{
    public string Source { get; set; } = string.Empty;
    public List<string> Recipients { get; set; } = new();
    public JobClosureDecisionNotificationData Data { get; set; } = new();
    public DateTime TimestampUtc { get; set; }
    public List<Links> Links { get; set; } = new();
}

public sealed class JobClosureDecisionNotificationData
{
    public Guid EventGuid { get; set; }
    public string EventType { get; set; } = string.Empty;
    public DateTime OccurredOnUtc { get; set; }

    public Guid? JobGuid { get; set; }
    public string? JobNumber { get; set; }
    public string? JobTitle { get; set; }

    // NEW
    public string? Description { get; set; }

    public int? OrganisationalUnitId { get; set; }
    public string? OrganisationalUnitName { get; set; }

    public int? WorkflowId { get; set; }
    public string? WorkflowName { get; set; }

    public int? StatusId { get; set; }
    public Guid? StatusGuid { get; set; }
    public string? StatusName { get; set; }

    public int? OldStatusId { get; set; }
    public Guid? OldStatusGuid { get; set; }
    public string? OldStatusName { get; set; }

    public string? Comment { get; set; }

    public JobClosureDecisionPerson? Actor { get; set; }
    public JobClosureDecisionLinkSet? Links { get; set; }
    public List<Links> LinksKv { get; set; } = new();
}

public sealed class JobClosureDecisionPerson
{
    public int? IdentityId { get; set; }
    public string? FullName { get; set; }
    public string? EmailAddress { get; set; }
}

public sealed class JobClosureDecisionLinkSet
{
    public string? JobUrl { get; set; }
    public string? JobRecordStatusUrl { get; set; }
}