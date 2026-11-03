namespace Concursus.API.Sage.SOAP.Models
{
    /// <summary>
    /// Response of the wrapper's GET /api/sales-allocations: what settled one
    /// invoice, as the SFA allocation sessions that invoice's URN is in.
    /// </summary>
    public sealed class SageFetchSalesAllocationsResponse
    {
        public string? Status { get; set; }
        public string? AccountReference { get; set; }
        public string? Urn { get; set; }

        /// <summary>
        /// Empty when the invoice has no allocations.
        /// </summary>
        public List<SageSalesAllocationSession> Sessions { get; set; } = new();
    }

    /// <summary>
    /// One SFA allocation session: the transactions matched against each other at one time.
    /// </summary>
    public sealed class SageSalesAllocationSession
    {
        public string? AllocationHeaderId { get; set; }

        /// <summary>
        /// YYYY-MM-DD.
        /// </summary>
        public string? SessionDate { get; set; }

        public List<SageSalesAllocationRow> Rows { get; set; } = new();
    }

    /// <summary>
    /// One side of a session. The requested invoice's own row has
    /// IsRequested = true and no counterpart fields. On every other row,
    /// TypeResolved says whether the wrapper could find the counterpart's
    /// type; when it is false, SysTraderTranType and the amounts are null.
    /// </summary>
    public sealed class SageSalesAllocationRow
    {
        public string? Urn { get; set; }

        /// <summary>
        /// YYYY-MM-DD.
        /// </summary>
        public string? TransactionDate { get; set; }

        /// <summary>
        /// Signed: positive for the invoice side, negative for a receipt or credit note.
        /// </summary>
        public decimal AllocationValue { get; set; }

        public bool IsRequested { get; set; }
        public bool TypeResolved { get; set; }
        public int? SysTraderTranType { get; set; }
        public string? TransactionReference { get; set; }
        public string? InstrumentNo { get; set; }
        public string? SecondReference { get; set; }
        public decimal? GrossAmount { get; set; }
        public decimal? TaxAmount { get; set; }
        public decimal? NetAmount { get; set; }
    }
}
