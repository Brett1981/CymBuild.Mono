namespace CymBuild_Outlook_Common.Models.SharePoint
{
    public class SaveToSharePointResponse
    {
        public string FullUrl { get; set; } = "";
        public string Status { get; set; } = "";

        // New (diagnostics)
        public string CorrelationId { get; set; } = "";
        public string DriveId { get; set; } = "";
        public string ItemId { get; set; } = "";
        public string Stage { get; set; } = "";              // e.g. "DriveResolve", "Upload", "SetPermissions"
        public string ErrorCode { get; set; } = "";          // e.g. "ODataError", "InsufficientPrivileges"
        public string ErrorMessage { get; set; } = "";       // sanitized message for UI
        public string GraphRequestId { get; set; } = "";     // request-id header (if available)
        public string GraphClientRequestId { get; set; } = "";// client-request-id (if you set one)
    }
}