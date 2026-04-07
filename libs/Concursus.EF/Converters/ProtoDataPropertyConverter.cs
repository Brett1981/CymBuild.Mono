using Concursus.Common.Shared.Models;
using Concursus.EF.Types;
using Google.Protobuf.WellKnownTypes;

namespace Concursus.EF.Converters
{
    public static class ProtoDataPropertyConverter
    {
        public static ProtoDataProperty ToProtoModel(DataProperty source)
        {
            return new ProtoDataProperty
            {
                EntityPropertyGuid = source.EntityPropertyGuid.ToString(),
                Value = source.Value,
                IsInvalid = source.IsInvalid,
                ValidationMessage = source.ValidationMessage,
                IsReadOnly = source.IsReadOnly,
                IsEnabled = source.IsEnabled,
                IsRestricted = source.IsRestricted,
                IsHidden = source.IsHidden,
                IsVirtual = source.IsVirtual
            };
        }

        public static IEnumerable<ProtoDataProperty> ToProtoModels(IEnumerable<DataProperty> properties)
        {
            return properties.Select(ToProtoModel);
        }

        public static Types.DataProperty FromProtoModel(ProtoDataProperty proto)
        {
            return new Types.DataProperty
            {
                EntityPropertyGuid = Guid.Parse(proto.EntityPropertyGuid),
                Value = proto.Value ?? new Any(),
                IsInvalid = proto.IsInvalid,
                ValidationMessage = proto.ValidationMessage,
                IsReadOnly = proto.IsReadOnly,
                IsEnabled = proto.IsEnabled,
                IsRestricted = proto.IsRestricted,
                IsHidden = proto.IsHidden,
                IsVirtual = proto.IsVirtual
            };
        }

        public static IEnumerable<Types.DataProperty> FromProtoModels(IEnumerable<ProtoDataProperty> protoProps)
        {
            return protoProps.Select(FromProtoModel);
        }
    }
}