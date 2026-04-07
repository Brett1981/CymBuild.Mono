namespace Concursus.EF.Types
{
    public class ActionMenuItem : IntTypeBase
    {
        #region Public Properties

        public Guid EntityQueryGuid { get; set; }
        public Guid EntityTypeGuid { get; set; }
        public string IconCss { get; set; } = "";
        public string Label { get; set; } = "";
        public int SortOrder { get; set; }
        public string Type { get; set; } = "";

        public bool RedirectToTargetGuid { get; set; } = false;

        #endregion Public Properties
    }
}