namespace CymBuild_Outlook_Common.Dto
{
    public class EmailUpsertDto
    {
        public Guid TargetObjectGuid { get; set; }
        public string Mailbox { get; set; }
        public string MessageID { get; set; }
        public string ConversationID { get; set; }
        public string FromAddress { get; set; }
        public string ToAddresses { get; set; }
        public string Subject { get; set; }
        public DateTime SentDateTime { get; set; }
        public bool DeliveryReceiptRequested { get; set; }
        public bool DeliveryReceiptReceived { get; set; }
        public bool ReadReceiptRequested { get; set; }
        public bool ReadReceiptReceived { get; set; }
        public bool DoNotFile { get; set; }
        public bool IsReadyToFile { get; set; }
        public DateTime? FiledDateTime { get; set; }
        public string FilingLocationUrl { get; set; } = "";
        public string Description { get; set; } = "";
        public Guid Guid { get; set; }
    }
}