namespace Concursus.API.Sage.Models
{
    public class Telephone
    {
        public int Id { get; set; }
        public string FullNumber { get; set; }
        public string CountryCode { get; set; }
        public string AreaCode { get; set; }
        public string SubscriberNumber { get; set; }
        public int CustomerContactId { get; set; }
        public bool IsDefault { get; set; }
        public bool IsToDelete { get; set; }
        public DateTime DateTimeCreated { get; set; }
        public DateTime DateTimeUpdated { get; set; }
    }
}