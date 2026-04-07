namespace Concursus.EF.Types
{
    public class MergeDocumentItemType
    {
        public short Id { get; set; }
        public Guid Guid { get; set; }
        public Enums.RowStatus RowStatus { get; set; }
        public string RowVersion { get; set; }
        public string Name { get; set; }
        public bool IsImageType { get; set; }
    }
}