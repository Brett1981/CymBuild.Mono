namespace Concursus.EF.Types;

public class ScheduleItem : BigIntTypeBase
{
    #region Public Properties

    public string Description { get; set; } = "";
    public DateTime EndDateTimeUTC { get; set; } = new();
    public string EndTimezone { get; set; } = "";
    public bool IsAllDay { get; set; }
    public string JobNumber { get; set; }
    public string RecurrenceExceptions { get; set; } = "";
    public int RecurrenceId { get; set; }
    public string RecurrenceRule { get; set; } = "";
    public DateTime StartDateTimeUTC { get; set; } = new();
    public string StartTimezone { get; set; } = "";
    public int StatusId { get; set; }
    public string Title { get; set; } = "";
    public int TypeId { get; set; }
    public int UserId { get; set; }

    #endregion Public Properties
}