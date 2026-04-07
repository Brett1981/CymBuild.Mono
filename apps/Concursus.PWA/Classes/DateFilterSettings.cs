namespace Concursus.PWA.Classes
{
    public class DateFilterSettings
    {
        public bool IsRangeFilter { get; set; }
        public string RangeStartParameter { get; set; }
        public string RangeEndParameter { get; set; }
        public string QuickFilterPresets { get; set; } // e.g., "7days,30days,custom"
    }
}