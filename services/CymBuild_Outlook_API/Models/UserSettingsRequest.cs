namespace CymBuild_Outlook_API.Models
{
    public class UserSettingsRequest
    {
        public bool MoveToCymBuildFiled { get; set; } = false;
        public bool ExtractAttachments { get; set; } = false;
        public string UserId { get; set; }
    }
}
