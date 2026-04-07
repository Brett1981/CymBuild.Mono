namespace Concursus.EF.Types
{
    public class DataObjectCompositeFilter
    {
        #region Public Fields

        public List<DataObjectCompositeFilter> CompositeFilters = new();
        public List<DataObjectFilter> Filters = new List<DataObjectFilter>();

        #endregion Public Fields

        #region Public Properties

        public string LogicalOperator { get; set; } = "";

        #endregion Public Properties
    }
}