using Microsoft.EntityFrameworkCore.Metadata.Internal;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("RowStatus", Schema = "SCore")]
public class RowStatus
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public byte ID { get; set; }

    [Required]
    [StringLength(50)]
    public string Name { get; set; }

    // Navigation properties (assuming they are collections of the related entities)
    public ICollection<OutlookEmailFromAddress> OutlookEmailFromAddresses { get; set; }

    public ICollection<OutlookCalendarEvent> OutlookCalendarEvents { get; set; }
    public ICollection<OutlookEmailConversation> OutlookEmailConversations { get; set; }
    public ICollection<OutlookEmailMailbox> OutlookEmailMailboxes { get; set; }
    public ICollection<OutlookEmail> OutlookEmails { get; set; }
    public ICollection<TargetObject> TargetObjects { get; set; }
    public ICollection<EntityType> EntityTypes { get; set; }
}