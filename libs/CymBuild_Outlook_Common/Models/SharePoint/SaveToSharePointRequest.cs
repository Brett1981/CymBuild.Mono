namespace CymBuild_Outlook_Common.Models.SharePoint
{
    public class SaveToSharePointRequest
    {
        public string AuthToken { get; set; } = "";
        public string MessageId { get; set; } = "";
        public string SharePointSiteId { get; set; } = "";
        public string SharePointFolderId { get; set; } = "";
        public string UserId { get; set; } = "";
        public Guid TargetObjectGuid { get; set; } = Guid.Empty;
        public Guid EntityTypeGuid { get; set; } = Guid.Empty;
        public bool DoNotFile { get; set; } = false;
        public string SubFolder { get; set; } = "";
        public int ProcessedCount { get; set; } = 0;
        public int TotalCount { get; set; } = 0;
        public IEnumerable<RecordSearchResult> RecordSearchResults { get; set; }
        public bool MoveToCymBuildFiled { get; set; } = false;
        public bool ExtractAttachments { get; set; } = false;
        public string Description { get; set; } = "";
    }
}