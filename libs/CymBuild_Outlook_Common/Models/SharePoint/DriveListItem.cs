using Google.Protobuf.WellKnownTypes;

namespace CymBuild_Outlook_Common.Models.SharePoint
{
    public class DriveListItem
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public Timestamp CreatedDateTime { get; set; }
        public Timestamp LastModifiedDateTime { get; set; }
        public long Size { get; set; }
        public string MimeType { get; set; }
        public string WebUrl { get; set; }
        public DriveListItem ParentFolder { get; set; }
        public SharePointFile SharePointFile { get; set; }
        public string ErrorReturned { get; set; }
    }

    public class SharePointFile
    {
        public FileHashes FileHashes { get; set; }
        public string MimeType { get; set; }
        public string FileType { get; set; }
        public string ShareId { get; set; }
        public bool Shared { get; set; }
        public string Owner { get; set; }
        public Timestamp CreatedDateTime { get; set; }
        public Timestamp LastModifiedDateTime { get; set; }
    }

    public class FileHashes
    {
        public int Crc32Hash { get; set; }
        public string QuickXorHash { get; set; }
        public string Sha1Hash { get; set; }
    }
}