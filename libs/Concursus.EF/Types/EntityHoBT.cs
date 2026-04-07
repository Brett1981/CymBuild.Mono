namespace Concursus.EF.Types
{
    public class EntityHoBT : IntTypeBase
    {
        #region Public Fields

        public List<ObjectSecurity> ObjectSecurity = new List<ObjectSecurity>();

        #endregion Public Fields

        #region Public Properties

        public Guid EntityTypeGuid { get; set; }
        public bool IsMainHoBT { get; set; }
        public bool IsReadOnlyOffline { get; set; }
        public string ObjectName { get; set; } = "";
        public string ObjectType { get; set; } = "";
        public string SchemaName { get; set; } = "";

        #endregion Public Properties
    }
}