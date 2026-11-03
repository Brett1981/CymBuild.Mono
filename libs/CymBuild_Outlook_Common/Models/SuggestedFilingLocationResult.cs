namespace CymBuild_Outlook_Common.Models
{
    public class SuggestedFilingLocationResult
    {
        public string FilingLocationUrl { get; set; } = "";
        public string Scope { get; set; } = "";
        public int FiledCount { get; set; }
        public DateTime? LastFiledDateTime { get; set; }
    }
}
