namespace Concursus.EF.Types
{
    public class MergeDocumentItemInclude
    {
        public Guid Guid { get; set; }
        public int SortOrder { get; set; }
        public string? SourceDocumentEntityProperty { get; set; }
        public string? SourceSharePointItemEntityProperty { get; set; }
        public string? IncludedMergeDocument { get; set; }
        public Guid MergeDocumentItemGuid { get; set; }
        public Enums.RowStatus RowStatus { get; set; }
        public string RowVersion { get; set; }
    }
}