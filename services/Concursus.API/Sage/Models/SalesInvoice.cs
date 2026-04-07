namespace Concursus.API.Sage.Models;

public class SalesInvoice
{
    public int CustomerId { get; set; }
    public DateTime TransactionDate { get; set; }
    public DateTime DueDate { get; set; }
    public decimal ExchangeRate { get; set; }
    public string Reference { get; set; }
    public string SecondReference { get; set; }
    public bool SettledImmediately { get; set; }
    public decimal DocumentGoodsValue { get; set; }
    public decimal DocumentTaxValue { get; set; }
    public decimal DocumentDiscountValue { get; set; }
    public decimal DocumentTaxDiscountValue { get; set; }
    public decimal DiscountPercent { get; set; }
    public int DiscountDays { get; set; }
    public bool TriangularTransaction { get; set; }
    public List<TaxAnalysisItem> TaxAnalysisItems { get; set; }
    public List<NominalAnalysisItem> NominalAnalysisItems { get; set; }

    // Constructor
    public SalesInvoice()
    {
        TaxAnalysisItems = new List<TaxAnalysisItem>();
        NominalAnalysisItems = new List<NominalAnalysisItem>();
    }
}