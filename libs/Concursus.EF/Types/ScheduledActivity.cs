namespace Concursus.EF.Types
{
    public class ScheduledActivity : IntTypeBase
    {
        #region Public Properties

        public int UserId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public string Title { get; set; }
        public string JobNumber { get; set; }

        public string Note { get; set; }

        #endregion Public Properties
    }
}