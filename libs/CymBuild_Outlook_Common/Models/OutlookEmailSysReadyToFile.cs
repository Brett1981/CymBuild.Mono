using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("OutlookEmails_Sys_ReadyToFile", Schema = "SOffice")]
public class OutlookEmailSysReadyToFile
{
    [Key]
    public long ID { get; set; }

    [Required]
    public Guid Guid { get; set; }

    [Required]
    public byte RowStatus { get; set; }

    [Timestamp]
    public byte[] RowVersion { get; set; }

    [Required]
    public int EntityTypeId { get; set; }

    [Required]
    public Guid EntityTypeGuid { get; set; }

    [Required]
    public long TargetObjectId { get; set; }

    [Required]
    public Guid TargetObjectGuid { get; set; }

    [Required]
    [Column(TypeName = "nvarchar(max)")]
    public string FilingLocation { get; set; }

    [Required]
    public int OutlookEmailMailboxID { get; set; }

    [Required]
    [StringLength(250)]
    public string MailboxName { get; set; }

    [StringLength(250)]
    public string MessageID { get; set; }

    [StringLength(250)]
    public string ConversationID { get; set; }

    [Required]
    public bool DeliveryReceiptRequested { get; set; }

    [Required]
    public bool DeliveryReceiptReceived { get; set; }

    [Required]
    public bool ReadReceiptRequested { get; set; }

    [Required]
    public bool ReadReceiptReceived { get; set; }
}