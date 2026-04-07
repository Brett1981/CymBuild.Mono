namespace Concursus.API.Sage.Models
{
    public class Customer
    {
        public int Id { get; set; }
        public string Reference { get; set; }
        public string Name { get; set; }
        public string ShortName { get; set; }
        public decimal Balance { get; set; }
        public bool OnHold { get; set; }
        public string StatusReason { get; set; }
        public string AccountStatusType { get; set; }
        public int CurrencyId { get; set; }
        public string ExchangeRateType { get; set; }
        public string TelephoneCountryCode { get; set; }
        public string TelephoneAreaCode { get; set; }
        public string TelephoneSubscriberNumber { get; set; }
        public string FaxCountryCode { get; set; }
        public string FaxAreaCode { get; set; }
        public string FaxSubscriberNumber { get; set; }
        public string Website { get; set; }
        public decimal CreditLimit { get; set; }
        public int CountryCodeId { get; set; }
        public int DefaultTaxCodeId { get; set; }
        public string VatNumber { get; set; }
        public string DunsCode { get; set; }
        public string AccountType { get; set; }
        public decimal EarlySettlementDiscountPercent { get; set; }
        public int EarlySettlementDiscountDays { get; set; }
        public int PaymentTermsDays { get; set; }
        public string PaymentTermsBasis { get; set; }
        public int AverageTimeToPay { get; set; }
        public bool TermsAgreed { get; set; }
        public decimal ValueOfCurrentOrdersInSop { get; set; }
        public int CreditBureauId { get; set; }
        public int CreditPositionId { get; set; }
        public string TradingTerms { get; set; }
        public string CreditReference { get; set; }
        public DateTime AccountOpened { get; set; }
        public DateTime LastCreditReview { get; set; }
        public DateTime NextCreditReview { get; set; }
        public DateTime ApplicationDate { get; set; }
        public DateTime DateReceived { get; set; }
        public DateTime DateFinanceChargeLastRun { get; set; }
        public string OrderPriority { get; set; }
        public bool UseTaxCodeAsDefault { get; set; }
        public int MonthsToKeepTransactions { get; set; }
        public int DefaultNominalCodeId { get; set; }
        public string DefaultNominalCodeReference { get; set; }
        public string DefaultNominalCodeCostCentre { get; set; }
        public string DefaultNominalCodeDepartment { get; set; }
        public decimal InvoiceDiscountPercent { get; set; }
        public decimal InvoiceLineDiscountPercent { get; set; }
        public int CustomerDiscountGroupId { get; set; }
        public int OrderValueDiscountId { get; set; }
        public int PriceBandId { get; set; }

        // Analysis Codes
        public string AnalysisCode1 { get; set; }

        // Add other analysis codes up to AnalysisCode20
        public string SpareText1 { get; set; }

        // Add other spare texts up to SpareText10
        public decimal SpareNumber1 { get; set; }

        // Add other spare numbers up to SpareNumber10
        public DateTime SpareDate1 { get; set; }

        // Add other spare dates up to SpareDate5
        public bool SpareBool1 { get; set; }

        // Add other spare bools up to SpareBool5
        public List<Alert> Alerts { get; set; }

        public List<Card> Cards { get; set; }
        public List<Contact> Contacts { get; set; }
        public DateTime DateTimeCreated { get; set; }
        public DateTime DateTimeUpdated { get; set; }

        // Constructor
        public Customer()
        {
            Alerts = new List<Alert>();
            Cards = new List<Card>();
            Contacts = new List<Contact>();
        }
    }
}