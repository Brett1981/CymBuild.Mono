using Google.Protobuf;
using Google.Protobuf.WellKnownTypes;
using Newtonsoft.Json;

namespace Concursus.API.Client.Classes
{
    public class DataProperty
    {
        public string EntityPropertyGuid { get; set; }
        public ProtoValue Value { get; set; }
        public bool IsInvalid { get; set; }
        public string ValidationMessage { get; set; }
    }

    public class ProtoValue
    {
        public string TypeUrl { get; set; }
        public ByteString Value { get; set; }

        // Convert this ProtoValue to an Any type
        public Any PackToAny()
        {
            switch (TypeUrl)
            {
                case "type.googleapis.com/google.protobuf.DoubleValue":
                    return Any.Pack(DoubleValue.Parser.ParseFrom(Value));

                case "type.googleapis.com/google.protobuf.StringValue":
                    return Any.Pack(StringValue.Parser.ParseFrom(Value));

                case "type.googleapis.com/google.protobuf.Timestamp":
                    return Any.Pack(Timestamp.Parser.ParseFrom(Value));

                case "type.googleapis.com/google.protobuf.BoolValue":
                    return Any.Pack(BoolValue.Parser.ParseFrom(Value));

                case "type.googleapis.com/google.protobuf.Int32Value":
                    return Any.Pack(Int32Value.Parser.ParseFrom(Value));

                default:
                    throw new InvalidOperationException("Unsupported type URL: " + TypeUrl);
            }
        }

        // Update this ProtoValue from an unpacked Any
        public void UnpackFromAny(Any packedValue)
        {
            switch (TypeUrl)
            {
                case "type.googleapis.com/google.protobuf.DoubleValue":
                    this.Value = DoubleValue.Parser.ParseFrom(packedValue.Value).ToByteString();
                    break;

                case "type.googleapis.com/google.protobuf.StringValue":
                    this.Value = StringValue.Parser.ParseFrom(packedValue.Value).ToByteString();
                    break;

                case "type.googleapis.com/google.protobuf.Timestamp":
                    this.Value = Timestamp.Parser.ParseFrom(packedValue.Value).ToByteString();
                    break;

                case "type.googleapis.com/google.protobuf.BoolValue":
                    this.Value = BoolValue.Parser.ParseFrom(packedValue.Value).ToByteString();
                    break;

                case "type.googleapis.com/google.protobuf.Int32Value":
                    this.Value = Int32Value.Parser.ParseFrom(packedValue.Value).ToByteString();
                    break;

                default:
                    throw new InvalidOperationException("Unsupported type URL: " + TypeUrl);
            }
        }
    }

    // Assuming this uses the DataObject from Concursus.API.Core
    public class ProtobufDataDecoder
    {
        public static Concursus.API.Core.DataObject DecodeDataObject(string jsonData)
        {
            var dataObject = JsonConvert.DeserializeObject<Concursus.API.Core.DataObject>(jsonData);

            //foreach (DataProperty prop in dataObject.DataProperties)
            //{
            //    if (prop.Value != null && prop.Value.Value != null && prop.Value.Value.Length > 0)
            //    {
            //        var packedValue = prop.Value.PackToAny();
            //        prop.Value.UnpackFromAny(packedValue);  // Unpack and update the ProtoValue
            //    }
            //}

            return dataObject;
        }
    }
}