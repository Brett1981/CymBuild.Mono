namespace Concursus.EF.Types
{
    public class EntityType : IntTypeBase
    {
        #region Public Fields

        public List<EntityHoBT> EntityHoBTs = new List<EntityHoBT>();
        public List<EntityProperty> EntityProperties = new List<EntityProperty>();
        public List<EntityPropertyGroup> EntityPropertyGroups = new List<EntityPropertyGroup>();
        public List<EntityQuery> EntityQueries = new List<EntityQuery>();
        public List<ObjectSecurity> ObjectSecurity = new List<ObjectSecurity>();

        #endregion Public Fields

        #region Public Properties

        public string DetailPageUrl { get; set; } = "";
        public bool DoNotTrackChanges { get; set; }
        public bool HasDocuments { get; set; }
        public string IconCss { get; set; } = "";
        public bool IsReadOnlyOffline { get; set; }
        public bool IsRequiredSystemData { get; set; }
        public bool IsRootEntity { get; set; }
        public string Label { get; set; } = "";
        public Guid LanguageLabelGuid { get; set; }
        public string Name { get; set; } = "";

        #endregion Public Properties
    }
}