namespace Concursus.EF.Types
{
    public class ExecuteEntityQueryResponse
    {
        #region Public Properties

        public DataObject DataObject { get; set; } = new();
        public bool ExitOnSuccess { get; set; }

        #endregion Public Properties
    }
}