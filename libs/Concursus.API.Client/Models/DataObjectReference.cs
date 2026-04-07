using Concursus.API.Client.Classes;

namespace Concursus.API.Client.Models
{
    public class DataObjectReference
    {
        #region Public Properties

        public Guid DataObjectGuid { get; set; }
        public Guid EntityTypeGuid { get; set; }

        #endregion Public Properties

        #region Constructor

        // Constructor to initialize the properties with parsed values
        public DataObjectReference(string dataObjectGuid, string entityTypeGuid)
        {
            DataObjectGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObjectGuid);
            EntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(entityTypeGuid);
        }

        #endregion Constructor
    }
}