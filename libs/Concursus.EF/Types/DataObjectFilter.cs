using Google.Protobuf.WellKnownTypes;

namespace Concursus.EF.Types
{
    public class DataObjectFilter
    {
        #region Public Properties

        public string ColumnName { get; set; } = "";
        public Guid Guid { get; set; }
        public string Operator { get; set; } = "";
        public Value Value { get; set; } = new();

        #endregion Public Properties
    }
}