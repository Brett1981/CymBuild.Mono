namespace Concursus.API.Sage.Models
{
    public class NominalAnalysisItem
    {
        public string Code { get; set; }
        public string CostCentre { get; set; }
        public string Department { get; set; }
        public string Narrative { get; set; }
        public decimal Value { get; set; }
        public string TransactionAnalysisCode { get; set; }
    }
}