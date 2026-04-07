namespace CymBuild_Outlook_Common.Dto
{
    public class RecordSearchDto
    {
        public int UserId { get; set; }
        public string SearchString { get; set; }
        public Guid EntityTypeGuid { get; set; }
        public string ToAddressesCSV { get; set; }
        public string FromAddress { get; set; }
        public string Subject { get; set; }
        public string MessageId { get; set; }
    }
}