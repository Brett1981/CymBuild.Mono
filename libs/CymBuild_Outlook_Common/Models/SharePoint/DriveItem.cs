namespace CymBuild_Outlook_Common.Models.SharePoint
{
    public class DriveItem
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string WebUrl { get; set; }
        public ItemReference ParentReference { get; set; }
        public string DriveId { get; set; }
        public DateTime CreatedDateTime { get; set; }
        public DateTime LastModifiedDateTime { get; set; }
        public long Size { get; set; }
        public string CTag { get; set; }
        public List<Permission> Permissions { get; set; }

        public class Permission
        {
            public string Id { get; set; }
            public string Roles { get; set; }
            public IdentitySet GrantedTo { get; set; }

            public class IdentitySet
            {
                public Identity User { get; set; }
                public Identity Application { get; set; }
                public Identity Device { get; set; }
            }

            public class Identity
            {
                public string Id { get; set; }
                public string DisplayName { get; set; }
            }
        }

        public class ItemReference
        {
            public string DriveId { get; set; }
            public string DriveType { get; set; }
            public string Id { get; set; }
            public string Path { get; set; }
        }
    }
}