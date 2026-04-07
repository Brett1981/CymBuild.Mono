using System.Text;

namespace CymBuild_Outlook_Common.Models
{
    public class MailRead
    {
        public string? ItemType { get; set; } = "";
        public string? Subject { get; set; }
        public string? Body { get; set; }
        public string? ItemId { get; set; }
        public string? ConversationId { get; set; }
        public MeetingInfo Meeting { get; set; } = new MeetingInfo(); // Renamed to MeetingInfo
        public SenderInfo Sender { get; set; } = new SenderInfo(); // Renamed to SenderInfo
        public List<RecipientInfo> ToRecipients { get; set; } = new List<RecipientInfo>(); // Renamed to RecipientInfo
        public List<RecipientInfo> CcRecipients { get; set; } = new List<RecipientInfo>();
        public List<RecipientInfo> BccRecipients { get; set; } = new List<RecipientInfo>();
        public List<AttachmentInfo> Attachments { get; set; } = new List<AttachmentInfo>(); // Renamed to AttachmentInfo
        public Dictionary<string, string> CustomProperties { get; set; } = new Dictionary<string, string>();

        public void DecodeBase64()
        {
            foreach (var attachment in Attachments)
            {
                string extension = Path.GetExtension(attachment.AttachmentName)?.ToLower() ?? string.Empty;
                // Check if the attachment is inline and if the file type is supported as an image
                if (!string.IsNullOrEmpty(attachment.AttachmentBase64Data) && attachment.Inline && IsImageFile(extension))
                {
                    attachment.AttachmentImageURL = $"data:image/{extension.TrimStart('.')};base64,{attachment.AttachmentBase64Data}";
                }
                else if (!string.IsNullOrEmpty(attachment.AttachmentBase64Data))
                {
                    // Handle non-image files differently, maybe just converting Base64 to text or
                    // setting a default icon
                    attachment.AttachmentContent = Encoding.UTF8.GetString(Convert.FromBase64String(attachment.AttachmentBase64Data));
                    attachment.AttachmentImageURL = GetDefaultIconForFileType(extension);
                }
            }
        }

        public bool IsImageFile(string extension)
        {
            return extension == ".jpg" || extension == ".jpeg" || extension == ".png" || extension == ".gif" || extension == ".bmp";
        }

        public string GetDefaultIconForFileType(string extension)
        {
            switch (extension)
            {
                case ".pdf":
                    return "bi-file-earmark-pdf fs-1";

                case ".doc":
                case ".docx":
                    return "bi-file-earmark-word fs-1";

                case ".xls":
                case ".xlsx":
                    return "bi-file-earmark-excel fs-1";

                case ".ppt":
                case ".pptx":
                    return "bi-file-earmark-ppt fs-1";

                case ".zip":
                case ".7z":
                case ".rar":
                    return "bi-file-earmark-zip fs-1"; // Bootstrap icon for ZIP which can be used for other compressed files
                case ".eml":
                    return "bi-envelope fs-1"; // Using the envelope icon for email files
                default:
                    return "bi-file-earmark fs-1";
            }
        }
    }

    public class MeetingInfo
    {
        public string? SeriesId { get; set; } = "";
        public DateTime? StartDateTime { get; set; } = null;
        public DateTime? EndDateTime { get; set; } = null;
    }

    public class SenderInfo
    {
        public string SenderName { get; set; } = "";
        public string SenderEmail { get; set; } = "";
    }

    public class RecipientInfo
    {
        public string Name { get; set; } = "";
        public string Email { get; set; } = "";
    }

    public class AttachmentInfo
    {
        public string? AttachmentId { get; set; }
        public string? AttachmentName { get; set; }
        public string? AttachmentType { get; set; }
        public bool Inline { get; set; }
        public string? ImmutableID { get; set; }
        public string? AttachmentBase64Data { get; set; }
        public string? AttachmentImageURL { get; set; }
        public string? AttachmentContent { get; set; }
    }
}