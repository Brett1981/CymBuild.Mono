using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("OutlookEmailFromAddresses", Schema = "SOffice")]
public class OutlookEmailFromAddress
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
    [StringLength(500)]
    public string Address { get; set; }

    [ForeignKey("RowStatus")]
    public virtual RowStatus RowStatusNavigation { get; set; }
}