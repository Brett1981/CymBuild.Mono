using Concursus.API.Core;
using Concursus.Common.Shared.Helpers;
using Google.Protobuf.WellKnownTypes;
using System.ComponentModel.DataAnnotations;

namespace Concursus.API.Client;

public class ScheduleViewItem
{
    #region Public Constructors

    public ScheduleViewItem()
    {
    }

    public ScheduleViewItem(ScheduleItem item)
    {
        Id = item.Id;
        Start = DateTimeHelper.NormalizeToLocal(item.Start);
        End = DateTimeHelper.NormalizeToLocal(item.End);
        Title = item.Title;
        Description = item.Description;
        UserId = item.UserId;
        StatusId = item.StatusId;
        TypeId = item.TypeId;
        IsAllDay = item.IsAllDay;
        RecurrenceRule = item.RecurrenceRule;
        RecurrenceId = item.RecurrenceId;
        RecurrenceExceptions = item.RecurrenceExceptions;
        StartTimezone = item.StartTimezone;
        EndTimezone = item.EndTimezone;
        JobNumber = item.JobNumber;
    }

    #endregion Public Constructors

    #region Public Properties

    public string Description { get; set; } = "";
    public DateTime End { get; set; }
    public string EndTimezone { get; set; } = "";
    public long Id { get; set; }

    public bool IsAllDay { get; set; }
    public string JobNumber { get; set; }
    public string RecurrenceExceptions { get; set; } = "";
    public int? RecurrenceId { get; set; }
    public string RecurrenceRule { get; set; } = "";
    public DateTime Start { get; set; }
    public string StartTimezone { get; set; } = "";

    public int? StatusId { get; set; }

    [Required] public string Title { get; set; } = "";

    public int? TypeId { get; set; }
    public int? UserId { get; set; }

    #endregion Public Properties

    #region Public Methods

    public ScheduleItem ToScheduleItem()
    {
        var item = new ScheduleItem()
        {
            Id = Id,
            Start = Timestamp.FromDateTime(Start),
            End = Timestamp.FromDateTime(End),
            Title = Title ?? "",
            Description = Description ?? "",
            UserId = UserId ?? 0,
            StatusId = StatusId ?? 0,
            TypeId = TypeId ?? 0,
            IsAllDay = IsAllDay,
            RecurrenceRule = RecurrenceRule ?? "",
            RecurrenceId = RecurrenceId ?? 0,
            RecurrenceExceptions = RecurrenceExceptions ?? "",
            StartTimezone = StartTimezone,
            EndTimezone = EndTimezone,
            JobNumber = JobNumber
        };

        return item;
    }

    #endregion Public Methods
}