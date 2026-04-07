namespace Sage200Microservice.Services.Models
{
    public class SageSalesOrder
    {
        public long id { get; set; }
        public string document_no { get; set; }
        public long customer_id { get; set; }
        public DateTime order_date { get; set; }
        public decimal document_gross_value { get; set; }
        public decimal document_outstanding_value { get; set; }
        public string trader_transaction_type { get; set; }
        public List<SageOrderLine> lines { get; set; }
        public List<SageAllocationHistoryItem> allocation_history_items { get; set; }
    }

    public class SageOrderLine
    {
        public string product_code { get; set; }
        public decimal quantity { get; set; }
        public decimal unit_price { get; set; }
    }

    public class SageAllocationHistoryItem
    {
        public string allocation_reference { get; set; }
        public decimal allocated_value { get; set; }
        public DateTime allocation_date { get; set; }
        public string trader_transaction_type { get; set; }
    }
}