namespace Sage200Microservice.Data.Models
{
    /// <summary>
    /// Represents the history of an invoice status check
    /// </summary>
    public class InvoiceStatusHistory
    {
        /// <summary>
        /// The unique identifier for the status history record
        /// </summary>
        public int Id { get; set; }

        /// <summary>
        /// The invoice reference
        /// </summary>
        public string InvoiceReference { get; set; }

        /// <summary>
        /// The outstanding value of the invoice at the time of the check
        /// </summary>
        public decimal OutstandingValue { get; set; }

        /// <summary>
        /// The allocated value of the invoice at the time of the check
        /// </summary>
        public decimal AllocatedValue { get; set; }

        /// <summary>
        /// The gross value of the invoice
        /// </summary>
        public decimal GrossValue { get; set; }

        /// <summary>
        /// The status of the invoice at the time of the check
        /// </summary>
        public string Status { get; set; } // "Paid", "Unpaid", "PartiallyPaid", "Credited"

        /// <summary>
        /// The timestamp of the check
        /// </summary>
        public DateTime CheckTimestamp { get; set; }

        /// <summary>
        /// The source of the check
        /// </summary>
        public string Source { get; set; } // "Manual", "Automated"

        /// <summary>
        /// The entity that performed the check
        /// </summary>
        public string CheckedBy { get; set; }

        /// <summary>
        /// The correlation ID for tracking
        /// </summary>
        public string CorrelationId { get; set; }
    }
}