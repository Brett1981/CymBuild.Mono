namespace Concursus.EF.Types
{
    public sealed class UserUsageLast7DaysData
    {
        public string Username { get; set; } = string.Empty;
        public Guid UserGuid { get; set; }
        public int UsageCountLast7Days { get; set; }
        public int UsageCountPrevious7Days { get; set; }
        public int ActiveDaysLast7Days { get; set; }
        public int FeaturesUsedLast7Days { get; set; }
        public DateTime? LastAccessedLast7Days { get; set; }
        public string UsageTrend { get; set; } = string.Empty;
    }
}
