namespace Concursus.EF.Types
{
    public class DataPill : IntTypeBase
    {
        #region Public Properties

        public string Class { get; set; } = "";
        public int SortOrder { get; set; }
        public string Value { get; set; } = "";

        #endregion Public Properties
    }
}