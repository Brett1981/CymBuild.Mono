namespace CymBuild_Outlook_Common.Models
{
    public class FilingRecordSearchResult
    {
        public long ID { get; set; }
        public Guid Guid { get; set; }
        public string EntityTypeName { get; set; } = "";
        public string Name { get; set; } = "";
        public int IsFiled { get; set; } = 0;
        public string FilingLocationUrl { get; set; } = "";
    }
}