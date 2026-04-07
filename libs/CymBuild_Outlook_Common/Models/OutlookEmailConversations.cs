using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("OutlookEmailConversations", Schema = "SOffice")]
public class OutlookEmailConversation
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long ID { get; set; }

    [Required]
    public Guid Guid { get; set; }

    [Required]
    public byte RowStatus { get; set; }

    [Timestamp]
    public byte[] RowVersion { get; set; }

    [Required]
    [StringLength(250)]
    public string ConversationID { get; set; }

    [ForeignKey("RowStatus")]
    public virtual RowStatus RowStatusNavigation { get; set; }
}