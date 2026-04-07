namespace Concursus.EF.Types
{
    public class DataObjectDeleteRequest
    {
        #region Public Fields

        public List<EntityQueryParameterValue> EntityQueryParameterValues = new List<EntityQueryParameterValue>();

        #endregion Public Fields

        #region Public Properties

        public DataObject DataObject { get; set; } = new();
        public Guid EntityQueryGuid { get; set; }

        #endregion Public Properties

        /*public Guid EntityTypeGuid { get; set; }
        public string ObjectRowVersion { get; set; } = "";
        public Guid ObjectGuid { get; set; }*/
    }
}