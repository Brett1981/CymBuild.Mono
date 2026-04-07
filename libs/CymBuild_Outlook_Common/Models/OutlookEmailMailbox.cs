using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("OutlookEmailMailboxes", Schema = "SOffice")]
public class OutlookEmailMailbox
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int ID { get; set; }

    [Required]
    public Guid Guid { get; set; }

    [Required]
    public byte RowStatus { get; set; }

    [Timestamp]
    public byte[] RowVersion { get; set; }

    [Required]
    [StringLength(250)]
    public string Name { get; set; }

    [ForeignKey("RowStatus")]
    public virtual RowStatus RowStatusNavigation { get; set; }
}