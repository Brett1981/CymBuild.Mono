namespace Sage200Microservice.Services.Models
{
    public class OrderLine
    {
        public string ProductCode { get; set; }
        public decimal Quantity { get; set; }
        public decimal UnitPrice { get; set; }
    }
}