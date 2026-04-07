namespace Concursus.EF.Types
{
    public class NonActivityEvents : IntTypeBase
    {
        #region Public Properties

        public int ID { get; set; }
        public string EventName { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public int TeamId { get; set; }
        public int MemberId { get; set; }
        public Guid Guid { get; set; }
        public int AbsenceTypeID { get; set; }

        #endregion Public Properties
    }
}