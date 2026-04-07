using Google.Protobuf.WellKnownTypes;

namespace Concursus.Common.Shared.Models
{
    public class ProtoDataProperty
    {
        public string EntityPropertyGuid { get; set; } = string.Empty;
        public Any? Value { get; set; }
        public bool IsInvalid { get; set; }
        public string ValidationMessage { get; set; } = string.Empty;
        public bool IsReadOnly { get; set; }
        public bool IsEnabled { get; set; }
        public bool IsRestricted { get; set; }
        public bool IsHidden { get; set; }
        public bool IsVirtual { get; set; }
    }
}