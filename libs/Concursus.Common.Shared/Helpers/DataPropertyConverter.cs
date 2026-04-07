using Concursus.Common.Shared.Models;
using Google.Protobuf.WellKnownTypes;

namespace Concursus.Common.Shared.Helpers
{
    public static class DataPropertyConverter
    {
        public static DataPropertyModel ToProto(DataPropertyModel model)
        {
            return new DataPropertyModel
            {
                EntityPropertyGuid = model.EntityPropertyGuid,
                Value = PackValue(model), // ⬅ packs correct type
                IsInvalid = model.IsInvalid,
                ValidationMessage = model.ValidationMessage ?? "",
                IsReadOnly = model.IsReadOnly,
                IsEnabled = model.IsEnabled,
                IsRestricted = model.IsRestricted,
                IsHidden = model.IsHidden,
                IsVirtual = model.IsVirtual
            };
        }

        public static string NormalizeDateTimeIfApplicable(string? value)
        {
            if (string.IsNullOrWhiteSpace(value)) return value ?? "";

            // Attempt to parse string as a DateTime or DateTimeOffset
            if (DateTime.TryParse(value, out var dt))
            {
                // Convert to UTC and reformat in ISO 8601
                return dt.Kind switch
                {
                    DateTimeKind.Local => dt.ToUniversalTime().ToString("o"),
                    DateTimeKind.Unspecified => DateTime.SpecifyKind(dt, DateTimeKind.Local).ToUniversalTime().ToString("o"),
                    DateTimeKind.Utc => dt.ToString("o"),
                    _ => dt.ToUniversalTime().ToString("o")
                };
            }

            return value;
        }

        public static Any NormalizeDateTimeIfApplicable(Any value)
        {
            if (value == null) return Any.Pack(new Empty());

            try
            {
                if (value.Is(Timestamp.Descriptor))
                {
                    value.TryUnpack(out Timestamp ts);
                    // Normalize to UTC (the Timestamp type is already in UTC, but just to be safe):
                    var dt = ts.ToDateTime();
                    var utc = DateTime.SpecifyKind(dt, DateTimeKind.Utc);
                    return Any.Pack(Timestamp.FromDateTime(utc));
                }

                // Add handling for DateTime stored as String if needed
                if (value.Is(StringValue.Descriptor))
                {
                    value.TryUnpack(out StringValue str);
                    string stringValue = str.Value;

                    // Only attempt to parse if the string matches one of our expected date formats
                    if (IsLikelyDateFormat(stringValue))
                    {
                        // Try to parse using specific formats
                        string[] formats = new[] {
                    "dd/MM/yyyy",
                    "dd-MM-yyyy",
                    "dd/MM/yyyy HH:mm:ss",
                    "dd-MM-yyyy HH:mm:ss",
                    "dd/MM/yyyy HH:mm",
                    "dd-MM-yyyy HH:mm"
                };

                        if (DateTime.TryParseExact(stringValue, formats,
                            System.Globalization.CultureInfo.InvariantCulture,
                            System.Globalization.DateTimeStyles.None, out var dt))
                        {
                            var utc = DateTime.SpecifyKind(dt, DateTimeKind.Local).ToUniversalTime();
                            return Any.Pack(Timestamp.FromDateTime(utc));
                        }
                    }
                }
            }
            catch
            {
                // Log or ignore and return as-is
            }

            return value; // return original if not datetime
        }

        // Helper method to do initial validation that the string resembles a date format
        private static bool IsLikelyDateFormat(string input)
        {
            if (string.IsNullOrWhiteSpace(input))
                return false;

            // Check if the string contains separators common in date formats
            bool containsDateSeparators = input.Contains('/') || input.Contains('-');

            if (containsDateSeparators)
            {
                // Pattern for dates without times
                string datePattern = @"^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}$";

                // Pattern for dates with times
                string dateTimePattern = @"^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\s\d{1,2}:\d{2}(:\d{2})?$";

                return System.Text.RegularExpressions.Regex.IsMatch(input, datePattern) ||
                       System.Text.RegularExpressions.Regex.IsMatch(input, dateTimePattern);
            }

            return false;
        }

        public static List<DataPropertyModel> ToProtoList(IEnumerable<DataPropertyModel> modelList)
        {
            return modelList.Select(ToProto).ToList();
        }

        private static Any PackValue(DataPropertyModel model)
        {
            if (model.AsString != null)
                return Any.Pack(new StringValue { Value = model.AsString });

            if (model.AsBool.HasValue)
                return Any.Pack(new BoolValue { Value = model.AsBool.Value });

            if (model.AsInt64.HasValue)
                return Any.Pack(new Int64Value { Value = model.AsInt64.Value });

            if (model.AsDouble.HasValue)
                return Any.Pack(new DoubleValue { Value = model.AsDouble.Value });

            if (model.AsDateTime.HasValue)
                return Any.Pack(Timestamp.FromDateTime(DateTime.SpecifyKind(model.AsDateTime.Value, DateTimeKind.Utc)));

            // Fallback: unknown value type or null
            return Any.Pack(new StringValue { Value = "" });
        }
    }
}