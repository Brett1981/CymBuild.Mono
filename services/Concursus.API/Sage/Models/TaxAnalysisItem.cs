namespace Concursus.API.Sage.Models
{
    public class TaxAnalysisItem
    {
        public string Id { get; set; }
        public decimal GoodsAmount { get; set; }
        public decimal DiscountAmount { get; set; }
        public decimal TaxAmount { get; set; }
        public decimal TaxDiscountAmount { get; set; }
    }
}