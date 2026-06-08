namespace Concursus.API.Models
{
    public sealed class SharePointStructureRepairRequestedPayload
    {
        public Guid DataObjectGuid { get; set; }
        public Guid EntityTypeGuid { get; set; }
        public string EntityQueryGuid { get; set; } = string.Empty;
        public DateTime RequestedOnUtc { get; set; }
    }
}
