namespace Concursus.EF.Types
{
    public class MergeDocument : IntTypeBase
    {
        #region Public Properties

        public string DocumentId { get; set; } = "";
        public string DriveId { get; set; } = "";
        public Guid EntityTypeGuid { get; set; }
        public string FilenameTemplate { get; set; } = "";
        public Guid LinkedEntityTypeGuid { get; set; }
        public string Name { get; set; } = "";

        public bool AllowPDFOnly { get; set; } = false;

        public bool AllowExcelOutputOnly { get; set; } = false;
        public bool ProduceOneOutputPerRow { get; set; } = false;

        // Child collections
        public List<MergeDocumentItem> Items { get; set; } = new();

        #endregion Public Properties
    }
}