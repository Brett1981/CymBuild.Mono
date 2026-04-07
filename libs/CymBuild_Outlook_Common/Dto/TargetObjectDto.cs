namespace CymBuild_Outlook_Common.Dto
{
    public class TargetObjectDto
    {
        public long ID { get; set; } // Changed to long to match bigint
        public int EntityTypeID { get; set; } // EntityTypeID remains int
        public string FilingLocation { get; set; }
        public Guid Guid { get; set; }
        public string Name { get; set; }
        public string Number { get; set; }
        public byte RowStatus { get; set; }
        public byte[] RowVersion { get; set; }
        public Guid EntityTypeGuid { get; set; }
        public string EntityTypeName { get; set; }
        public byte EntityTypeRowStatus { get; set; }
        public byte[] EntityTypeRowVersion { get; set; }
    }
}