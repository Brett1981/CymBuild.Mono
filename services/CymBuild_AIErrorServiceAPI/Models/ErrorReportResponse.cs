namespace CymBuild_AIErrorServiceAPI.Models
{
    public class ErrorReportResponse
    {
        public string Hash { get; set; }
        public string AiSummary { get; set; }
        public string JiraTicketKey { get; set; }
        public string JiraDescription { get; set; } = "";
        public string ErrorMessage { get; set; } = "";
        public string JiraUrl { get; set; }
        public string JiraStatus { get; set; }
        public bool AlreadyExists { get; set; }
        public string? JiraError { get; set; }
    }
}