namespace Concursus.EF.Types
{
    public class RecentItem
    {
        #region Public Properties

        public DateTime DateTime { get; set; }
        public string DetailPageUri { get; set; } = "";
        public Guid EntityTypeGuid { get; set; }
        public string EntityTypeLabel { get; set; } = "";
        public string Label { get; set; } = "";
        public Guid RecordGuid { get; set; }
        public Guid UserGuid { get; set; }

        #endregion Public Properties
    }
}