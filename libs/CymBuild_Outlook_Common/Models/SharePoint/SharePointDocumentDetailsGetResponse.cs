namespace CymBuild_Outlook_Common.Models.SharePoint
{
    public class SharePointDocumentDetailsGetResponse
    {
        public List<DriveListItem> DriveListItem { get; set; } = new List<DriveListItem>();
        public string ErrorReturned { get; set; }
    }
}