using Google.Protobuf.WellKnownTypes;

namespace Concursus.PWA.Helpers
{
    public static class UiFormattingHelper
    {
        /// <summary>
        /// Formats a nullable DateTime for display based on type context.
        /// </summary>
        /// <param name="value">      The DateTime value to format. </param>
        /// <param name="isDateOnly"> True for 'DATE' fields, false for 'DATETIME2'. </param>
        /// <returns> Formatted string or empty string if null. </returns>
        public static string FormatDateForUI(DateTime? value, bool isDateOnly)
        {
            if (value == null) return string.Empty;

            var localValue = value.Value.ToLocalTime();

            return isDateOnly
                ? localValue.ToString("dd MMM yyyy")
                : localValue.ToString("dd MMM yyyy HH:mm");
        }

        public static DateTime EnsureNoUtcRollback(DateTime input)
        {
            if (input.TimeOfDay == TimeSpan.Zero)
            {
                // Apply a default "safe" time (e.g., 12:00 PM) to avoid BST/UTC shift issues
                return new DateTime(input.Year, input.Month, input.Day, 12, 0, 0, input.Kind);
            }

            return input;
        }

        public static DateTime EnsureNoUtcRollback(DateTimeOffset input)
        {
            if (input.TimeOfDay == TimeSpan.Zero)
            {
                // Apply a default "safe" time (e.g., 12:00 PM) to avoid BST/UTC shift issues
                return new DateTime(input.Year, input.Month, input.Day, 12, 0, 0, DateTimeKind.Unspecified);
            }
            return input.DateTime;
        }

        public static Timestamp ToTimestamp(DateTime dateTime)
        {
            if (dateTime.Kind == DateTimeKind.Unspecified)
            {
                // Assume it was originally UTC (from .ToDateTime() on a Timestamp)
                dateTime = DateTime.SpecifyKind(dateTime, DateTimeKind.Utc);
            }

            var utc = NormalizeToUtc(dateTime);
            return Timestamp.FromDateTime(utc.UtcDateTime);
        }

        public static Timestamp ToTimestamp(DateTimeOffset dto)
        {
            return Timestamp.FromDateTime(dto.UtcDateTime);
        }

        public static string FormatDynamicDate(string columnName, DateTime dt)
        {
            bool isDateOnly = columnName.ToLower().EndsWith("date") && !columnName.ToLower().Contains("time");
            return FormatDateForUI(dt, isDateOnly);
        }

        public static bool IsDateEmpty(DateTime? date) => !date.HasValue || date.Value == DateTime.MinValue;

        public static DateTimeOffset NormalizeToUtc(DateTime localOrUnspecified)
        {
            return localOrUnspecified.Kind switch
            {
                DateTimeKind.Utc => new DateTimeOffset(localOrUnspecified, TimeSpan.Zero),
                DateTimeKind.Local => localOrUnspecified.ToUniversalTime(),
                _ => DateTime.SpecifyKind(localOrUnspecified, DateTimeKind.Local).ToUniversalTime()
            };
        }

        /// <summary>
        /// Converts a DateTime to local time, ensuring the input is interpreted as UTC if unspecified.
        /// </summary>
        public static DateTime NormalizeToLocal(DateTime dt)
        {
            // Treat as UTC if unspecified, then convert to local
            if (dt.Kind == DateTimeKind.Unspecified)
                dt = DateTime.SpecifyKind(dt, DateTimeKind.Utc);

            return dt.ToLocalTime();
        }

        /// <summary>
        /// Converts a DateTime or DateTimeOffset to a packed Any Timestamp (in UTC).
        /// </summary>
        /// <param name="value"> The date-time value (assumed local unless explicitly UTC). </param>
        /// <returns> Packed Any containing Timestamp in UTC </returns>
        public static Any PackUtcTimestamp(object value)
        {
            if (value is DateTime dt)
            {
                var utc = NormalizeToUtc(dt);
                return Any.Pack(Timestamp.FromDateTime(utc.UtcDateTime));
            }
            else if (value is DateTimeOffset dto)
            {
                return Any.Pack(Timestamp.FromDateTime(dto.UtcDateTime));
            }

            throw new ArgumentException("Value must be DateTime or DateTimeOffset", nameof(value));
        }

        public static DateTime NormalizeToLocal(Timestamp timestamp)
        {
            return NormalizeToLocal(timestamp.ToDateTime());
        }

        public static bool UnpackBool(Any packedValue)
        {
            return packedValue.Unpack<BoolValue>().Value;
        }

        public static double UnpackDouble(Any packedValue)
        {
            return packedValue.Unpack<DoubleValue>().Value;
        }

        public static int UnpackInt32(Any packedValue)
        {
            return packedValue.Unpack<Int32Value>().Value;
        }

        public static long UnpackInt64(Any packedValue)
        {
            return packedValue.Unpack<Int64Value>().Value;
        }

        public static string UnpackString(Any packedValue)
        {
            return packedValue.Unpack<StringValue>().Value;
        }

        public static DateTime UnpackTimestamp(Any packedValue)
        {
            return packedValue.Unpack<Timestamp>().ToDateTimeOffset().UtcDateTime;
        }
    }
}