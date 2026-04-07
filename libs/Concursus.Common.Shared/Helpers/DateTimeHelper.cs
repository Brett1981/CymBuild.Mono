using Google.Protobuf.WellKnownTypes;

namespace Concursus.Common.Shared.Helpers
{
    public static class DateTimeHelper
    {
        #region Public Methods

        public static DateTime FromTimestamp(Timestamp ts) =>
            NormalizeToLocal(ts.ToDateTime());

        public static DateTimeOffset FromTimestampOffset(Timestamp ts) =>
            ts.ToDateTimeOffset().ToLocalTime();

        public static DateTime? FromTimestampSafe(Timestamp? ts) =>
            ts == null ? null : FromTimestamp(ts);

        public static DateTime FromTimestampUtc(Timestamp ts)
        {
            return DateTime.SpecifyKind(ts.ToDateTime(), DateTimeKind.Utc);
        }

        public static DateTime NormalizeToLocal(Timestamp timestamp)
        {
            var utc = timestamp.ToDateTime();
            return DateTime.SpecifyKind(utc, DateTimeKind.Utc).ToLocalTime();
        }

        // Normalize any DateTime to Local
        public static DateTime NormalizeToLocal(DateTime dt)
        {
            return dt.Kind switch
            {
                DateTimeKind.Local => dt,
                DateTimeKind.Utc => dt.ToLocalTime(),
                _ => DateTime.SpecifyKind(dt, DateTimeKind.Utc).ToLocalTime()
            };
        }

        // Normalize any DateTime to UTC
        public static DateTime NormalizeToUtc(DateTime dt)
        {
            return dt.Kind switch
            {
                DateTimeKind.Utc => dt,
                DateTimeKind.Local => dt.ToUniversalTime(),
                _ => DateTime.SpecifyKind(dt, DateTimeKind.Local).ToUniversalTime()
            };
        }

        public static DateTimeOffset NormalizeToUtcOffset(DateTime dt)
        {
            return dt.Kind switch
            {
                DateTimeKind.Utc => new DateTimeOffset(dt, TimeSpan.Zero),
                DateTimeKind.Local => dt.ToUniversalTime(),
                _ => DateTime.SpecifyKind(dt, DateTimeKind.Local).ToUniversalTime()
            };
        }

        public static string ToFormattedLocalString(Timestamp? ts, string format = "dd/MM/yyyy HH:mm") =>
            ts == null ? "" : FromTimestamp(ts).ToString(format);

        // Timestamp ↔ DateTime/DateTimeOffset
        public static Timestamp ToTimestamp(DateTime dt) =>
            Timestamp.FromDateTime(NormalizeToUtc(dt));

        public static Timestamp ToTimestamp(DateTimeOffset dto) =>
            Timestamp.FromDateTimeOffset(dto.ToUniversalTime());

        public static Timestamp ToUtcTimestamp(DateTime input)
        {
            if (input.Kind != DateTimeKind.Utc)
                input = DateTime.SpecifyKind(input, DateTimeKind.Utc);

            return Timestamp.FromDateTime(input);
        }

        #endregion Public Methods
    }
}