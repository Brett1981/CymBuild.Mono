namespace Concursus.API.Sage.Models
{
    public class Contact
    {
        public int Id { get; set; }
        public int CustomerId { get; set; }
        public int SalutationId { get; set; }
        public string Name { get; set; }
        public string FirstName { get; set; }
        public string MiddleName { get; set; }
        public string LastName { get; set; }
        public string DefaultTelephone { get; set; }
        public string DefaultEmail { get; set; }
        public bool IsDefault { get; set; }

        public bool IsToDelete { get; set; }

        // Assuming Salutation is another class/model you'd define public Salutation Salutation {
        // get; set; }
        public List<Email> Emails { get; set; }

        public List<Telephone> Telephones { get; set; }
        public List<Mobile> Mobiles { get; set; }
        public List<Fax> Faxes { get; set; }
        public List<Website> Websites { get; set; }
        public List<Role> Roles { get; set; }
        public DateTime DateTimeCreated { get; set; }
        public DateTime DateTimeUpdated { get; set; }

        public Contact()
        {
            Emails = new List<Email>();
            Telephones = new List<Telephone>();
            Mobiles = new List<Mobile>();
            Faxes = new List<Fax>();
            Websites = new List<Website>();
            Roles = new List<Role>();
        }
    }
}