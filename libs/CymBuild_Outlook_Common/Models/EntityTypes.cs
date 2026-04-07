using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("EntityTypes", Schema = "SOffice")]
public class EntityType
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int ID { get; set; }

    [Required]
    public Guid Guid { get; set; }

    [Required]
    [ForeignKey("RowStatusNavigation")]
    public byte RowStatus { get; set; }

    [Required]
    public byte[] RowVersion { get; set; }

    [Required]
    [StringLength(250)]
    public string Name { get; set; }

    // Navigation properties
    public virtual RowStatus RowStatusNavigation { get; set; }

    public virtual ICollection<TargetObject> TargetObjects { get; set; }
}