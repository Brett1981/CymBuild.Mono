namespace Concursus.API.Sage.Models
{
    public class Role
    {
        public int Id { get; set; }
        public int CustomerContactId { get; set; }
        public int TraderContactRoleId { get; set; } // Assuming this links to a specific role definition
        public bool IsPreferredContactForRole { get; set; }
        public bool IsToDelete { get; set; }
        public DateTime DateTimeCreated { get; set; }
        public DateTime DateTimeUpdated { get; set; }
    }
}