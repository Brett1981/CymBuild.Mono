namespace Concursus.API.Sage.Models
{
    public class Email
    {
        public int Id { get; set; }
        public string EmailAddress { get; set; }
        public int CustomerContactId { get; set; }
        public bool IsDefault { get; set; }
        public bool IsToDelete { get; set; }
        public DateTime DateTimeCreated { get; set; }
        public DateTime DateTimeUpdated { get; set; }
    }
}