namespace CymBuild_Outlook_Common.Dto
{
    public class FilingRecordSearchDto
    {
        public int ID { get; set; }
        public Guid Guid { get; set; }
        public string EntityTypeName { get; set; }
        public string Name { get; set; }
        public bool IsFiled { get; set; }
        public string FilingLocationUrl { get; set; }
    }
}