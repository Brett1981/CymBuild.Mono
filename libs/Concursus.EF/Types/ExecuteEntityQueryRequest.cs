namespace Concursus.EF.Types
{
    public class ExecuteEntityQueryRequest
    {
        #region Public Fields

        public List<EntityQueryParameterValue> EntityQueryParameterValues = new();

        #endregion Public Fields

        #region Public Properties

        public DataObject DataObject { get; set; } = new();
        public Guid EntityQueryGuid { get; set; }

        #endregion Public Properties
    }
}