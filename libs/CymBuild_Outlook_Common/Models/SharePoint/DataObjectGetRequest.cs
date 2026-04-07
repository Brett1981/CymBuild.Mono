namespace CymBuild_Outlook_Common.Models.SharePoint
{
    public class DataObjectGetRequest
    {
        public string Guid { get; set; }
        public string EntityTypeGuid { get; set; }
        public string EntityQueryGuid { get; set; }
        public bool ForInformationView { get; set; }
        public List<string> ObjectGuids { get; set; } = new List<string>();
    }
}