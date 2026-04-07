namespace Concursus.EF.Types
{
    public class EntityQuery : IntTypeBase
    {
        #region Public Fields

        public List<EntityQueryParameter> EntityQueryParameters = new List<EntityQueryParameter>();

        #endregion Public Fields

        #region Public Properties

        public Guid EntityHoBTGuid { get; set; }
        public Guid EntityTypeGuid { get; set; }
        public bool IsDefaultCreate { get; set; }
        public bool IsDefaultDataPills { get; set; }
        public bool IsDefaultDelete { get; set; }
        public bool IsDefaultProgressData { get; set; }
        public bool IsDefaultRead { get; set; }
        public bool IsDefaultUpdate { get; set; }
        public bool IsDefaultValidation { get; set; }
        public bool IsMergeDocumentQuery { get; set; }
        public bool IsScalarExecute { get; set; }
        public string Name { get; set; } = "";
        public string Statement { get; set; } = "";

        #endregion Public Properties
    }
}