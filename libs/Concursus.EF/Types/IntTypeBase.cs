namespace Concursus.EF.Types
{
    public class IntTypeBase
    {
        #region Public Properties

        public Guid Guid { get; set; }
        public int Id { get; set; }
        public Enums.RowStatus RowStatus { get; set; }

        public string RowVersion { get; set; } = "";

        #endregion Public Properties
    }
}