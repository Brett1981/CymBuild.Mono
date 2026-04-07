using Concursus.API.Core;
using Concursus.Common.Shared.Models;

namespace Concursus.API.Helpers
{
    public static class DataPropertyModelConverter
    {
        public static IEnumerable<DataPropertyModel> Convert(IEnumerable<DataPropertyModel> grpcProperties)
        {
            var convertedList = new List<DataPropertyModel>();

            foreach (var p in grpcProperties)
            {
                convertedList.Add(new DataPropertyModel
                {
                    EntityPropertyGuid = p.EntityPropertyGuid,
                    Value = p.Value,
                    IsInvalid = p.IsInvalid,
                    ValidationMessage = p.ValidationMessage,
                    IsReadOnly = p.IsReadOnly,
                    IsEnabled = p.IsEnabled,
                    IsRestricted = p.IsRestricted,
                    IsHidden = p.IsHidden,
                    IsVirtual = p.IsVirtual
                });
            }

            return convertedList;
        }

        public static DataPropertyModel ToModel(DataPropertyModel proto)
        {
            return new DataPropertyModel
            {
                EntityPropertyGuid = proto.EntityPropertyGuid,
                Value = proto.Value,
                IsInvalid = proto.IsInvalid,
                ValidationMessage = proto.ValidationMessage,
                IsReadOnly = proto.IsReadOnly,
                IsEnabled = proto.IsEnabled,
                IsRestricted = proto.IsRestricted,
                IsHidden = proto.IsHidden,
                IsVirtual = proto.IsVirtual
            };
        }

        public static DataPropertyModel ToModel(ProtoDataProperty proto)
        {
            return new DataPropertyModel
            {
                EntityPropertyGuid = proto.EntityPropertyGuid,
                Value = proto.Value,
                IsInvalid = proto.IsInvalid,
                ValidationMessage = proto.ValidationMessage,
                IsReadOnly = proto.IsReadOnly,
                IsEnabled = proto.IsEnabled,
                IsRestricted = proto.IsRestricted,
                IsHidden = proto.IsHidden,
                IsVirtual = proto.IsVirtual
            };
        }

        public static ProtoDataProperty FromProto(DataProperty proto)
        {
            return new ProtoDataProperty
            {
                EntityPropertyGuid = proto.EntityPropertyGuid,
                Value = proto.Value,
                IsInvalid = proto.IsInvalid,
                ValidationMessage = proto.ValidationMessage,
                IsReadOnly = proto.IsReadOnly,
                IsEnabled = proto.IsEnabled,
                IsRestricted = proto.IsRestricted,
                IsHidden = proto.IsHidden,
                IsVirtual = proto.IsVirtual
            };
        }

        public static IEnumerable<DataPropertyModel> ToModels(IEnumerable<DataProperty> protoProperties)
        {
            return protoProperties
                .Select(FromProto)
                .Select(ToModel);
        }
    }
}