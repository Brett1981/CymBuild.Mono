namespace Concursus.EF.Types
{
    /// <summary>
    /// Class definition of the data for the quote dashboard.
    /// </summary>
    public class QuoteDashboardData : IntTypeBase
    {
        //[EXISTING FIELDS IN THE DATABASE]
        public int? QuoteID { get; set; }

        public string? QuoteNumber { get; set; }

        public string Guid { get; set; }
        public DateTime Date { get; set; }
        public string Status { get; set; }
        public string Client { get; set; }
        public string QuoteType { get; set; }
        public decimal QuoteValue { get; set; }

        //[CALCULATED FIELDS]
        public string? Label { get; set; }

        public double? Value { get; set; }
        public double? Min { get; set; }
        public double? Max { get; set; }
    }
}