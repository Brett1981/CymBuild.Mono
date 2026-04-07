namespace CymBuild_AIErrorServiceAPI.Dto
{
    public class AiStatusDto
    {
        public string JiraStatus { get; set; }
        public string JiraPriority { get; set; }
        public string JiraDescription { get; set; } = "";
        public string AIAnalysis { get; set; } = "";
        public DateTime? JiraLastSyncedUtc { get; set; }
    }
}