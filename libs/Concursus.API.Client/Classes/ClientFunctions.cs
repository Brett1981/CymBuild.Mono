using Concursus.API.Client.Models;
using Google.Protobuf.Collections;
using System.Text.RegularExpressions;

namespace Concursus.API.Client.Classes
{
    public static class ClientFunctions
    {
        #region Public Methods

        //public static Any ConvertToDataProperty(DataProperty newProperty, object? value, string entityDataTypeName)
        //{
        //    if (value != null) return Any.Pack(null);
        //    switch (entityDataTypeName.ToLower())
        //    {
        //        case "nvarchar":
        //        case "nvarchar(max)":
        //            StringValue stringValue = new() { Value = "" };
        //            newProperty.Value = Any.Pack(stringValue);
        //            break;

        // case "int": case "smallint": case "tinyint": Int32Value int32Value = new() { Value = 0 };
        // newProperty.Value = Any.Pack(int32Value); break;

        // case "bigint": Int64Value int64Value = new() { Value = 0 }; newProperty.Value =
        // Any.Pack(int64Value); break;

        // case "double": DoubleValue doubleValue = new() { Value = 0 }; newProperty.Value =
        // Any.Pack(doubleValue); break;

        // case "bit": BoolValue boolValue = new() { Value = false }; newProperty.Value =
        // Any.Pack(boolValue); break;

        // case "uniqueidentifier": StringValue guidValue = new() { Value = Guid.Empty.ToString() };
        // newProperty.Value = Any.Pack(guidValue); break;

        // case "date": case "datetime2": newProperty.Value = Any.Pack(new Empty()); break; }

        //    return newProperty.Value;
        //}
        public static void ResetStateService(StateService stateService)
        {
            stateService.OriginalRecordItem = Guid.Empty.ToString();
            stateService.OriginalRecordType = Guid.Empty.ToString();
            stateService.OriginalRecordGuid = Guid.Empty.ToString();
            stateService.ChildRecordItem = Guid.Empty.ToString();
            stateService.ChildRecordType = Guid.Empty.ToString();
            stateService.ChildRecordGuid = Guid.Empty.ToString();
        }

        public static bool IsBetweenTwoDates(this DateTime dt, DateTime start, DateTime end)
        {
            if (dt <= start) return false;
            return dt < end;
        }

        public static Guid ParseAndReturnEmptyGuidIfInvalid(string inputGuid)
        {
            if (Guid.TryParse(inputGuid, out var parsedGuid))
                return parsedGuid;
            else
                // Return an empty Guid if the inputGuid is not a valid Guid
                return Guid.Empty;
        }

        public static List<Guid> ParseAndReturnListEmptyGuidIfInvalid(RepeatedField<string>? objectGuids)
        {
            List<Guid> result = [];
            if (objectGuids != null)
                result.AddRange(objectGuids.Select(objectGuid =>
                    Guid.TryParse(objectGuid, out var parsedGuid) ? parsedGuid : Guid.Empty));
            return result;
        }

        public static string SanitizeFileName(string fileName)
        {
            // Define a regex pattern to match illegal characters
            string pattern = "[\\\\/:*?\"<>|#%]+";

            // Replace illegal characters with an empty string
            string sanitizedFileName = Regex.Replace(fileName, pattern, "");

            // Trim any leading or trailing dots or spaces
            sanitizedFileName = sanitizedFileName.Trim('.', ' ');

            return sanitizedFileName;
        }

        #endregion Public Methods
    }
}