namespace CymBuild_Outlook_Common.Models
{
    public class FrequentFilingRecordResult
    {
        public long ID { get; set; }
        public Guid Guid { get; set; }
        public string EntityTypeName { get; set; } = "";
        public string Name { get; set; } = "";
        public int FiledCount { get; set; }
        public DateTime? LastFiledDateTime { get; set; }
    }
}
