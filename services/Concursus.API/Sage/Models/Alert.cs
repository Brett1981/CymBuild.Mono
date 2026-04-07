namespace Concursus.API.Sage.Models
{
    public class Alert
    {
        public int Id { get; set; }
        public int CustomerId { get; set; }
        public string AlertText { get; set; }
        public bool IsActive { get; set; }
        public bool ShowAlertForOrders { get; set; }
        public bool ShowAlertForProformas { get; set; }
        public bool ShowAlertForQuotes { get; set; }
        public bool ShowAlertForCreditNotes { get; set; }
        public bool ShowAlertForPriceEnquiries { get; set; }
        public bool ShowAlertForInvoices { get; set; }
        public bool ShowAlertForReturns { get; set; }
        public bool ShowAlertForProjectBills { get; set; }
        public bool IsToDelete { get; set; }
        public string UpdatedBy { get; set; }
        public DateTime DateTimeCreated { get; set; }
        public DateTime DateTimeUpdated { get; set; }
    }
}