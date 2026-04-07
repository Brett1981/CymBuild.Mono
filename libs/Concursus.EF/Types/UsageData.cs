namespace Concursus.EF.Types
{
    public class UsageData : IntTypeBase
    {
        #region Public Properties

        public string Username { get; set; } = "";
        public string FeatureName { get; set; } = "";
        public int UsageCount { get; set; }
        public int WeeklyAverage { get; set; }
        public string FirstAccessed { get; set; } = "";
        public string LastAccessed { get; set; } = "";

        #endregion Public Properties
    }
}