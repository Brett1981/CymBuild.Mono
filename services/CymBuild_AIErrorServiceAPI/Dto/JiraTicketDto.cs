namespace CymBuild_AIErrorServiceAPI.Dto
{
    public class JiraTicketDto
    {
        public string Key { get; set; }
        public string Summary { get; set; }
        public string Status { get; set; }
        public string Url { get; set; }
        public string JiraPriority { get; set; }
        public string JiraDescription { get; set; } = string.Empty;
        public DateTime? JiraLastSyncedUtc { get; set; }
    }
}