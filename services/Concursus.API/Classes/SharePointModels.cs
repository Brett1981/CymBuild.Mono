using Microsoft.Graph.Models;

namespace Concursus.API.Classes;

public class SharePointModels
{
    #region Public Classes

    public class Document
    {
        #region Public Properties

        public string? CreatedBy { get; set; }
        public DateTimeOffset? CreatedDateTime { get; set; }
        public File File { get; internal set; }
        public string? Id { get; set; }
        public string? LastModifiedBy { get; set; }
        public DateTimeOffset? LastModifiedDateTime { get; set; }
        public string? Name { get; set; }
        public List<Permission> Permission { get; set; }
        public long? Size { get; set; }
        public string? WebUrl { get; set; }

        #endregion Public Properties
    }

    public class File
    {
        #region Public Properties

        public Hashes Hashes { get; internal set; }
        public string? MimeType { get; set; }

        #endregion Public Properties
    }

    public class Hashes
    {
        #region Public Properties

        public string? QuickXorHash { get; set; }
        public string? Sha1Hash { get; set; }

        #endregion Public Properties
    }

    #endregion Public Classes
}