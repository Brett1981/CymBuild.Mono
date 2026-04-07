using Google.Protobuf.WellKnownTypes;

namespace CymBuild_Outlook_Common.Models.SharePoint
{
    public class SharePointSite
    {
        // Unique identifier for the site.
        public string Id { get; set; }

        // Display name of the site.
        public string DisplayName { get; set; }

        // Web URL of the site.
        public string WebUrl { get; set; }

        // Date and time when the site was created.
        public Timestamp CreatedDateTime { get; set; }

        // Description of the site.
        public string Description { get; set; }

        // Date and time when the site was last modified.
        public Timestamp LastModifiedDateTime { get; set; }

        // Name of the site.
        public string Name { get; set; }

        // Root URL of the site.
        public string Root { get; set; }
    }
}