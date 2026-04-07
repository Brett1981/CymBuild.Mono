namespace Concursus.EF.Types
{
    public class UserPreferences : IntTypeBase
    {
        #region Public Properties

        public int ID { get; set; }
        public Guid Guid { get; set; }
        public int SystemLanguageID { get; set; }
        public string WidgetLayout { get; set; } = ""; //CBLD-408

        #endregion Public Properties
    }
}