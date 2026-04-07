namespace CymBuild_Outlook_Common.Dto
{
    public class CalendarEventUpsertDto
    {
        public Guid TargetObjectGuid { get; set; }
        public string Mailbox { get; set; }
        public string ExchangeImmutableID { get; set; }
        public string Title { get; set; }
        public DateTime StartDateTime { get; set; }
        public DateTime EndDateTime { get; set; }
        public bool IsAllDay { get; set; }
        public string Recurrence { get; set; }
        public string LastUpdateSource { get; set; }
        public Guid Guid { get; set; }
    }
}