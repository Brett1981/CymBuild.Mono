namespace CymBuild_Outlook_Common.Dto
{
    public class TargetObjectUpsertDto
    {
        public Guid EntityTypeGuid { get; set; }
        public Guid RecordGuid { get; set; }
        public string Number { get; set; }
        public string Name { get; set; }
        public string FilingLocation { get; set; }
    }
}