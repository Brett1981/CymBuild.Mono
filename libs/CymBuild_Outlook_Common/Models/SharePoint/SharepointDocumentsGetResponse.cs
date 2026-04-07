namespace CymBuild_Outlook_Common.Models.SharePoint
{
    public class SharepointDocumentsGetResponse
    {
        public DriveItem DriveItem { get; set; }
        public string DownloadUrl { get; set; }
        public string ErrorReturned { get; set; }
    }
}