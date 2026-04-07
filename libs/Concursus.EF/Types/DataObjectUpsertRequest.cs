namespace Concursus.EF.Types
{
    public class DataObjectUpsertRequest
    {
        #region Public Fields

        public List<EntityQueryParameterValue> EntityQueryParameterValues = new();

        #endregion Public Fields

        #region Public Properties

        public DataObject DataObject { get; set; } = new();
        public Guid EntityQueryGuid { get; set; }
        public bool SkipValidation { get; set; } = false;
        public bool ValidateOnly { get; set; }
        public DataObject DeltaDataObject { get; set; } = new(); //CBLD-436

        #endregion Public Properties
    }
}