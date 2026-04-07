namespace Concursus.EF.Types
{
    public class PublicHoliday : IntTypeBase
    {
        #region Public Properties

        public int ID { get; set; }
        public DateTime Date { get; set; }
        public string DayName { get; set; }
        public string MonthName { get; set; }
        public string YearInWords { get; set; }
        public string FormattedDate { get; set; }
        public string HolidayName { get; set; }
        public bool IsBankHoliday { get; set; }
        public string Region { get; set; }
        public int FiscalQuarter { get; set; }
        public int FiscalYear { get; set; }
        public int DayOfYear { get; set; }
        public int WeekOfYear { get; set; }

        #endregion Public Properties
    }
}