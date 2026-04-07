namespace Concursus.EF.Types
{
    public class EntityProperty : IntTypeBase
    {
        #region Public Fields

        public List<EntityPropertyDependant> DependantProperties = new List<EntityPropertyDependant>();
        public List<ObjectSecurity> ObjectSecurity = new List<ObjectSecurity>();
        public List<EntityPropertyActions> PropertyActions = new List<EntityPropertyActions>();

        #endregion Public Fields

        #region Public Properties

        public string DetailPageUri { get; set; } = "";
        public bool DoNotTrackChanges { get; set; }
        public DropDownListDefinition? DropDownListDefinition { get; set; }
        public Guid DropDownListDefinitionGuid { get; set; }
        public Guid EntityDataTypeGuid { get; set; }
        public string EntityDataTypeName { get; set; } = "";
        public Guid EntityHoBTGuid { get; set; }
        public Guid EntityPropertyGroupGuid { get; set; }
        public Guid EntityTypeGuid { get; set; }
        public string FixedDefaultValue { get; set; } = "";
        public Guid ForeignEntityTypeGuid { get; set; }
        public int GroupSortOrder { get; set; }
        public string InformationPageUri { get; set; } = "";
        public bool IsCompulsory { get; set; }
        public bool IsDetailWindowed { get; set; }
        public bool IsHidden { get; set; }
        public bool IsImmutable { get; set; }
        public bool IsIncludedInformation { get; set; }
        public bool IsLatitude { get; set; }
        public bool IsLongitude { get; set; }
        public bool IsObjectLabel { get; set; }
        public bool IsParentRelationship { get; set; }
        public bool IsReadOnly { get; set; }
        public bool IsUppercase { get; set; }
        public string Label { get; set; } = "";
        public Guid LanguageLabelGuid { get; set; }
        public int MaxLength { get; set; }
        public string Name { get; set; } = "";
        public int Precision { get; set; }
        public int Scale { get; set; }
        public int SortOrder { get; set; }
        public string SqlDefaultValueStatement { get; set; } = "";

        public bool AllowBulkChange { get; set; } //CBLD-260
        public bool SelectedForBulkChange { get; set; } = false; //CBLD-260
        public string Value { get; set; } = ""; //CBLD-260
        public bool IsSelectedForBulkChange { get; set; } = false; //CBLD-260

        public bool IsVirtual { get; set; } //1. OE: CBLD-473
        public bool ShowOnMobile { get; set; }
        public bool IsAlwaysVisibleInGroup { get; set; }
        public bool IsAlwaysVisibleInGroup_Mobile { get; set; }
        public string ExternalSearchPageUrl { get; set; }

        #endregion Public Properties
    }
}