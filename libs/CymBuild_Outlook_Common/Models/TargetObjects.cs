using Microsoft.EntityFrameworkCore.Metadata.Internal;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("TargetObjects", Schema = "SOffice")]
public class TargetObject
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long ID { get; set; }

    [Required]
    public Guid Guid { get; set; }

    [Required]
    public byte RowStatus { get; set; }

    [Required]
    public byte[] RowVersion { get; set; }

    [Required]
    [StringLength(250)]
    public string Name { get; set; }

    [StringLength(100)]
    public string Number { get; set; }

    [Required]
    public int EntityTypeId { get; set; }

    [Column(TypeName = "nvarchar(max)")]
    public string FilingLocation { get; set; }

    // Navigation properties
    public virtual EntityType EntityType { get; set; }

    public virtual ICollection<OutlookCalendarEvent> CalendarEvents { get; set; }
    public virtual ICollection<OutlookEmail> Emails { get; set; }
}