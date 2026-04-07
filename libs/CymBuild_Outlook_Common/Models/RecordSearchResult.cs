namespace CymBuild_Outlook_Common.Models
{
    public class RecordSearchResult
    {
        public long ID { get; set; }  // Adjusted to match BIGINT in SQL
        public Guid Guid { get; set; }
        public string EntityTypeName { get; set; }
        public string Name { get; set; }
        public int SearchRank { get; set; }
        public bool? ConversationMatch { get; set; }
        public bool? ToMatch { get; set; }
        public bool? FromMatch { get; set; }
        public bool? RecordMatch { get; set; }
    }
}