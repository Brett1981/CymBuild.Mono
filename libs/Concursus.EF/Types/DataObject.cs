namespace Concursus.EF.Types
{
    public class DataObject : BigIntTypeBase
    {
        #region Public Fields

        public List<ActionMenuItem> ActionMenuItems = new List<ActionMenuItem>();
        public List<DataPill> DataPills = new List<DataPill>();
        public List<DataProperty> DataProperties = new List<DataProperty>();
        public List<MergeDocument> MergeDocuments = new List<MergeDocument>();
        public List<ObjectSecurity> ObjectSecurity = new List<ObjectSecurity>();
        public List<ValidationResult> ValidationResults = new List<ValidationResult>();

        #endregion Public Fields

        #region Public Properties

        public long DatabaseId { get; set; }
        public Guid EntityTypeGuid { get; set; }
        public bool HasDocuments { get; set; }
        public bool HasValidationMessages { get; set; }
        public string Label { get; set; } = "";
        public ProgressData ProgressData { get; set; } = new ProgressData();
        public string SharePointFolderPath { get; set; } = "";
        public string SharePointSiteIdentifier { get; set; } = "";
        public string SharePointUrl { get; set; } = "";
        public string ErrorReturned { get; set; } = "";

        public bool SaveButtonDisabled { get; set; }  //CBLD-382

        #endregion Public Properties
    }
}