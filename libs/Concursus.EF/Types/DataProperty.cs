using Google.Protobuf.WellKnownTypes;

namespace Concursus.EF.Types
{
    public class DataProperty
    {
        #region Public Properties

        public Guid EntityPropertyGuid { get; set; }
        public bool IsEnabled { get; set; }
        public bool IsHidden { get; set; }
        public bool IsInvalid { get; set; }
        public bool IsReadOnly { get; set; }
        public bool IsRestricted { get; set; }
        public string ValidationMessage { get; set; } = "";
        public Any Value { get; set; } = new();

        public bool IsVirtual { get; set; } //OE: CBLD-473

        #endregion Public Properties
    }
}