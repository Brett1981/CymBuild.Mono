namespace Concursus.EF.Types
{
    public class MergeDocumentItem
    {
        public Guid Guid { get; set; }
        public string? MergeDocumentItemType { get; set; }
        public string? BookmarkName { get; set; }
        public string? EntityType { get; set; }
        public Guid? EntityTypeGuid { get; set; }
        public Guid? LinkedEntityTypeGuid { get; set; }
        public string? SubFolderPath { get; set; }
        public int? ImageColumns { get; set; }
        public Enums.RowStatus RowStatus { get; set; }
        public string RowVersion { get; set; }

        public List<MergeDocumentItemInclude> Includes { get; set; } = new();
    }
}