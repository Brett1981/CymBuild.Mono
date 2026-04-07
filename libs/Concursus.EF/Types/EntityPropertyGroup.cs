namespace Concursus.EF.Types
{
    public class EntityPropertyGroup : IntTypeBase
    {
        #region Public Properties

        public string Label { get; set; } = "";
        public Guid LanguageLabelGuid { get; set; }
        public string Layout { get; set; } = "";
        public string Name { get; set; } = "";
        public int SortOrder { get; set; }
        public bool ShowOnMobile { get; set; } = false;
        public bool IsCollapsable { get; set; } = false;
        public bool IsDefaultCollapsed { get; set; } = false;
        public bool IsDefaultCollapsed_Mobile { get; set; } = false;

        #endregion Public Properties
    }
}