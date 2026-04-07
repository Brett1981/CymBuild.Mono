namespace Concursus.EF.Types
{
    public class SharePointDetail
    {
        #region Public Properties

        public string Name { get; set; } = "";
        public string ParentName { get; set; } = "";
        public long ParentObjectId { get; set; }
        public int ParentPrimaryKeySplitInterval { get; set; }
        public int ParentStructureId { get; set; }
        public bool ParentUseLibraryPerSplit { get; set; }
        public int PrimaryKeySplitInterval { get; set; }
        public string SiteIdentifier { get; set; } = "";
        public bool UseLibraryPerSplit { get; set; }

        #endregion Public Properties
    }
}