namespace CymBuild_Outlook_Common.Models
{
    public class Mailbox
    {
        public UserProfile UserProfile { get; set; }
        public ItemInfo Item { get; set; } // Ensure this class is appropriately named
    }

    public class UserProfile
    {
        public string DisplayName { get; set; }
        public string EmailAddress { get; set; }
        public string Id { get; set; }
    }

    public class ItemInfo // Ensure this class matches the structure expected
    {
        public string ItemId { get; set; }
        public string Subject { get; set; }
        public string Body { get; set; }
        public SenderInfo Sender { get; set; }
        public List<RecipientInfo> ToRecipients { get; set; }
        public List<RecipientInfo> CcRecipients { get; set; }
        public List<RecipientInfo> BccRecipients { get; set; }
        public List<AttachmentInfo> Attachments { get; set; }
        public string ConversationId { get; set; }
        public MeetingInfo Meeting { get; set; }
    }
}