namespace CymBuild_Outlook_Common.Dto
{
    public class EmailSysProcessingUpdateDto
    {
        public bool DeliveryReceiptReceived { get; set; }
        public bool ReadReceiptReceived { get; set; }
        public DateTime FiledDateTime { get; set; }
        public Guid Guid { get; set; }
    }
}