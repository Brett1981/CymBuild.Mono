using Google.Protobuf.WellKnownTypes;

namespace Concursus.API.Helpers
{
    public static class DateTimeHelper
    {
        /// <summary>
        /// Converts a nullable DateTimeOffset to a Google.Protobuf Timestamp.
        /// </summary>
        public static Timestamp? ToTimestamp(DateTimeOffset? dateTimeOffset)
        {
            if (dateTimeOffset == null)
                return null;

            // Convert to UTC before assigning to ensure consistency
            return Timestamp.FromDateTime(dateTimeOffset.Value.UtcDateTime);
        }

        /// <summary>
        /// Converts a nullable DateTime to a Google.Protobuf Timestamp.
        /// </summary>
        public static Timestamp? ToTimestamp(DateTime? dateTime)
        {
            if (dateTime == null)
                return null;

            // Assume unspecified/local as UTC if kind is unknown
            return Timestamp.FromDateTime(dateTime.Value.Kind == DateTimeKind.Unspecified
                ? DateTime.SpecifyKind(dateTime.Value, DateTimeKind.Utc)
                : dateTime.Value.ToUniversalTime());
        }

        /// <summary>
        /// Converts a Timestamp to a nullable DateTimeOffset in UTC.
        /// </summary>
        public static DateTimeOffset? FromTimestamp(Timestamp? timestamp)
        {
            return timestamp?.ToDateTime().ToUniversalTime();
        }

        /// <summary>
        /// Converts a Timestamp? to a UTC DateTime string (e.g. "yyyy-MM-dd HH:mm:ss").
        /// </summary>
        public static string ToUtcString(Timestamp? timestamp, string format = "yyyy-MM-dd HH:mm:ss")
        {
            return timestamp?.ToDateTime().ToUniversalTime().ToString(format) ?? "";
        }

        /// <summary>
        /// Converts a Timestamp to a Microsoft Graph-compatible DateTimeTimeZone object.
        /// </summary>
        public static Microsoft.Graph.Models.DateTimeTimeZone ToDateTimeTimeZone(Timestamp? timestamp)
        {
            return new Microsoft.Graph.Models.DateTimeTimeZone
            {
                DateTime = ToUtcString(timestamp),
                TimeZone = "UTC"
            };
        }
    }
}