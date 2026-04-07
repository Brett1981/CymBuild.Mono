namespace Sage200Microservice.Services.Models
{
    public class SageCustomer
    {
        public long id { get; set; }
        public string customer_code { get; set; }
        public string name { get; set; }
        public SageCustomerAddress main_address { get; set; }
        public string telephone { get; set; }
        public string email { get; set; }
        // Add other relevant properties as needed
    }

    public class SageCustomerAddress
    {
        public string address_1 { get; set; }
        public string address_2 { get; set; }
        public string address_3 { get; set; }
        public string town { get; set; }
        public string postcode { get; set; }
        public string county { get; set; }
        public string country { get; set; }
    }
}