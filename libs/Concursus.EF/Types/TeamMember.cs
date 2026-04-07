namespace Concursus.EF.Types
{
    public class TeamMember
    {
        public int IdentityId { get; set; }              // Matches [ID] in SQL
        public Guid Guid { get; set; }                   // Matches [Guid] ROWGUIDCOL
        public string FullName { get; set; } = string.Empty;
        public string EmailAddress { get; set; } = string.Empty;
        public string JobTitle { get; set; } = string.Empty;
        public int OrganisationalUnitId { get; set; }
        public bool IsActive { get; set; }
        public string Color { get; set; } = "#ffa500";    // Optional: used in Scheduler
        public byte[] Signature { get; set; } = Array.Empty<byte>(); // Matches [Signature]
    }
}