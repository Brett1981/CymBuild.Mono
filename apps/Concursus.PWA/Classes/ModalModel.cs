using Concursus.API.Client.Models;

namespace Concursus.PWA.Classes
{
    public class ModalModel
    {
        public string ModalId { get; set; } = Guid.Empty.ToString();
        public string DataObjectGuid { get; set; } = Guid.Empty.ToString();
        public string EntityTypeGuid { get; set; } = Guid.Empty.ToString();

        public DataObjectReference DataObjectReference { get; set; } =
           new DataObjectReference(Guid.Empty.ToString(), Guid.Empty.ToString());

        public DateTime Timestamp { get; set; }
    }
}