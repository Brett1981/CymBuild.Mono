using Google.Protobuf.WellKnownTypes;

namespace Concursus.Common.Shared.Models
{
    public class DataPropertyModel
    {
        public string EntityPropertyGuid { get; set; }
        public Any Value { get; set; }
        public bool IsInvalid { get; set; }
        public string ValidationMessage { get; set; }
        public bool IsReadOnly { get; set; }
        public bool IsEnabled { get; set; }
        public bool IsRestricted { get; set; }
        public bool IsHidden { get; set; }
        public bool IsVirtual { get; set; }

        // Optional: Expose Unpacked Values for debugging/UI
        public string? AsString => Value?.Is(StringValue.Descriptor) == true
            && Value.TryUnpack(out StringValue s)
            ? s.Value : null;

        public DateTime? AsDateTime => Value?.Is(Timestamp.Descriptor) == true
            && Value.TryUnpack(out Timestamp ts)
            ? ts.ToDateTime().ToLocalTime()
            : null;

        public double? AsDouble => Value?.Is(DoubleValue.Descriptor) == true
            && Value.TryUnpack(out DoubleValue d)
            ? d.Value : null;

        public bool? AsBool => Value?.Is(BoolValue.Descriptor) == true
            && Value.TryUnpack(out BoolValue b)
            ? b.Value : null;

        public long? AsInt64 => Value?.Is(Int64Value.Descriptor) == true
            && Value.TryUnpack(out Int64Value i64)
            ? i64.Value : null;

        public int? AsInt32 => Value?.Is(Int32Value.Descriptor) == true
            && Value.TryUnpack(out Int32Value i32)
            ? i32.Value : null;
    }
}