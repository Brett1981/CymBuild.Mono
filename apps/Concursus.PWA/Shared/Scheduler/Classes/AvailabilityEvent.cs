namespace Concursus.PWA.Shared.Scheduler.Classes
{
    public class AvailabilityEvent
    {
        public int Id { get; set; }
        public string Title { get; set; } = "";
        public int TeamMemberId { get; set; }
        public string TeamMemberNameAsString { get; set; }
        public DateTime Start { get; set; }
        public DateTime End { get; set; }
        public string CssClass { get; set; } = "";
        public bool IsAbsence { get; set; }
        public bool IsAllDay { get; set; } = false;
        public string JobNumber { get; set; } = "";
        public string Note { get; set; } = "";

        public string Guid { get; set; } = "00000000-0000-0000-0000-000000000000";

        public int AbsenceTypeID { get; set; } = -1; //Set to -1 which is "undefined"
    }
}