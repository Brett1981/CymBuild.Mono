using Google.Protobuf.WellKnownTypes;

namespace Concursus.EF.Types
{
    public class EntityQueryParameterValue
    {
        #region Public Properties

        public string Name { get; set; } = "";
        public Any Value { get; set; } = new();

        #endregion Public Properties
    }
}