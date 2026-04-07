using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("Preferences", Schema = "SOffice")]
public class Preference
{
    [Key]
    [ForeignKey("OutlookEmailMailbox")]
    [DatabaseGenerated(DatabaseGeneratedOption.None)] // Assuming ID is not auto-generated since it's a foreign key.
    public int ID { get; set; }

    [Required]
    public Guid Guid { get; set; }

    [Required]
    [ForeignKey("RowStatusNavigation")]
    public byte RowStatus { get; set; }

    [Required]
    public byte[] RowVersion { get; set; }

    [Required]
    public int OutlookMailboxID { get; set; }

    public int AutoFileMinutes { get; set; }

    [Required]
    public bool IsAutoFilingEnabled { get; set; }

    [Required]
    public bool MoveFiledToFiledItems { get; set; }

    [StringLength(2000)]
    public string SharedMailboxesToCheck { get; set; }

    // Navigation properties
    public virtual OutlookEmailMailbox OutlookEmailMailbox { get; set; }

    public virtual RowStatus RowStatusNavigation { get; set; }
}