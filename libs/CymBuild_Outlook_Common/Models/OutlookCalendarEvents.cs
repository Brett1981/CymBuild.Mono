using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("OutlookCalendarEvents", Schema = "SOffice")]
public class OutlookCalendarEvent
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long ID { get; set; }

    [Required]
    public Guid Guid { get; set; }

    [Required]
    [ForeignKey("RowStatusNavigation")]
    public byte RowStatus { get; set; }

    [Required]
    public byte[] RowVersion { get; set; }

    [ForeignKey("TargetObject")]
    public long? TargetObjectID { get; set; }

    [Required]
    [ForeignKey("OutlookEmailMailbox")]
    public int OutlookEmailMailboxID { get; set; }

    [StringLength(250)]
    public string ExchangeImmutableID { get; set; }

    [Required]
    [StringLength(2000)]
    public string Title { get; set; }

    [Column(TypeName = "datetime2")]
    public DateTime StartDateTime { get; set; }

    [Column(TypeName = "datetime2")]
    public DateTime EndDateTime { get; set; }

    [Required]
    public bool IsAllDay { get; set; }

    [Column(TypeName = "nvarchar(max)")]
    public string Recurrence { get; set; }

    [StringLength(1)]
    public string LastUpdateSource { get; set; }

    // Navigation properties
    public virtual RowStatus RowStatusNavigation { get; set; }

    public virtual OutlookEmailMailbox EmailMailbox { get; set; }
    public virtual TargetObject TargetObject { get; set; }
}