using Concursus.Common.Shared.Models;
using Google.Protobuf.WellKnownTypes;

namespace Concursus.Common.Shared.Helpers
{
    public static class DataObjectDebugHelper
    {
        public static string UnpackValue(Any value)
        {
            if (value == null) return "(null)";
            try
            {
                if (value.Is(Timestamp.Descriptor))
                {
                    value.TryUnpack(out Timestamp ts);
                    return $"Timestamp: {ts.ToDateTime().ToLocalTime():yyyy-MM-dd HH:mm:ss} (Local)";
                }
                if (value.Is(StringValue.Descriptor))
                {
                    value.TryUnpack(out StringValue str);
                    return $"String: \"{str.Value}\"";
                }
                if (value.Is(Int32Value.Descriptor))
                {
                    value.TryUnpack(out Int32Value i32);
                    return $"Int32: {i32.Value}";
                }
                if (value.Is(Int64Value.Descriptor))
                {
                    value.TryUnpack(out Int64Value i64);
                    return $"Int64: {i64.Value}";
                }
                if (value.Is(BoolValue.Descriptor))
                {
                    value.TryUnpack(out BoolValue b);
                    return $"Bool: {b.Value}";
                }
                if (value.Is(DoubleValue.Descriptor))
                {
                    value.TryUnpack(out DoubleValue d);
                    return $"Double: {d.Value}";
                }
                if (value.Is(UInt32Value.Descriptor))
                {
                    value.TryUnpack(out UInt32Value u32);
                    return $"UInt32: {u32.Value}";
                }

                return "(Unknown packed type)";
            }
            catch (Exception ex)
            {
                return $"(Error unpacking: {ex.Message})";
            }
        }

        /// <summary>
        /// Dumps pre-converted list of DataPropertyModels (used internally).
        /// </summary>
        public static void DumpDataProperties(IEnumerable<DataPropertyModel> models)
        {
            foreach (var prop in models)
            {
                var valueSummary = UnpackValue(prop.Value);
                Console.WriteLine($"[{prop.EntityPropertyGuid}] = {valueSummary}");
            }
        }

        /// <summary> Only Run During Debugging. Accepts gRPC RepeatedField<DataProperty> and
        /// automatically converts & dumps. </summary>
        public static void DumpDataProperties(IEnumerable<ProtoDataProperty> protoProps)
        {
#if DEBUG
            foreach (var prop in protoProps)
            {
                var valueSummary = UnpackValue(prop.Value);
                Console.WriteLine($"EntityPropertyGuid: [{prop.EntityPropertyGuid}] = {valueSummary}");
            }
#endif
        }
    }
}