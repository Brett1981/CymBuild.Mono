using System;
using System.Collections.Generic;
using System.Text;

namespace CymBuild_Outlook_Common.Dto
{
    public class SharePointFolderDto
    {
        public string Id { get; set; } = "";
        public string Name { get; set; } = "";
        public string WebUrl { get; set; } = "";
        public string? ParentId { get; set; }
        public string? DriveId { get; set; }
        public string Path { get; set; } = string.Empty;
    }
}
