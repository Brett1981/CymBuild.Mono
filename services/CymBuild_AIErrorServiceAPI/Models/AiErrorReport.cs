namespace CymBuild_AIErrorServiceAPI.Models
{
    public class AiErrorReport
    {
        public int Id { get; set; }
        public string Hash { get; set; } = default!;
        public string UserId { get; set; } = default!;
        public string ErrorMessage { get; set; } = default!;
        public string StackTrace { get; set; } = default!;
        public string ContextJson { get; set; } = default!;
        public string AiAnalysis { get; set; }
        public string JiraDescription { get; set; } = string.Empty;
        public string JiraTicketKey { get; set; }
        public string JiraUrl { get; set; }
        public string JiraStatus { get; set; }
        public DateTime CreatedUtc { get; set; }
        public bool JiraTicketCreated { get; set; }
        public bool IsResolved { get; set; }
        public DateTime? JiraLastSyncedUtc { get; set; }
        public string? JiraPriority { get; set; }
    }
}