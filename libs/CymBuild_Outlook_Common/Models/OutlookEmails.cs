using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("OutlookEmails", Schema = "SOffice")]
public class OutlookEmail
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long ID { get; set; }

    [Required]
    public Guid Guid { get; set; }

    [Required]
    public byte[] RowVersion { get; set; }

    [Required]
    public byte RowStatus { get; set; }  // Renamed to RowStatusID

    [ForeignKey("RowStatus")]
    public virtual RowStatus RowStatusNavigation { get; set; }

    [ForeignKey("TargetObject")]
    public long? TargetObjectID { get; set; }

    [Required]
    public int OutlookEmailMailboxID { get; set; }  // Assume this is set correctly with the FK attribute elsewhere

    [StringLength(250)]
    public string MessageID { get; set; }

    [Required]
    public long OutlookEmailConversationId { get; set; }  // Assume FK is set correctly elsewhere

    [Required]
    public int OutlookEmailFromAddressID { get; set; }  // Assume FK is set correctly elsewhere

    [StringLength(4000)]
    public string ToAddresses { get; set; }

    [StringLength(2000)]
    public string Subject { get; set; }

    public DateTime? SentDateTime { get; set; }

    [Required]
    public bool DeliveryReceiptRequested { get; set; }

    [Required]
    public bool DeliveryReceiptReceived { get; set; }

    [Required]
    public bool ReadReceiptRequested { get; set; }

    [Required]
    public bool ReadReceiptReceived { get; set; }

    [Required]
    public bool DoNotFile { get; set; }

    [Required]
    public bool IsReadyToFile { get; set; }

    public DateTime? FiledDateTime { get; set; }

    [StringLength(500)]
    public string FilingLocationUrl { get; set; }

    [StringLength(4000)]
    public string Description { get; set; }

    // Navigation properties (assume these are configured correctly with FK attributes elsewhere)
    public virtual OutlookEmailMailbox EmailMailbox { get; set; }

    public virtual OutlookEmailConversation EmailConversation { get; set; }
    public virtual OutlookEmailFromAddress EmailFromAddress { get; set; }
    public virtual TargetObject TargetObject { get; set; }
}