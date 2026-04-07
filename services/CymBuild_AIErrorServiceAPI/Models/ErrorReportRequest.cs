namespace CymBuild_AIErrorServiceAPI.Models
{
    public class ErrorReportRequest
    {
        public string UserId { get; set; } = default!;
        public string ErrorMessage { get; set; } = default!;
        public string StackTrace { get; set; } = default!;
        public string ContextJson { get; set; }

        public string Description { get; set; } = "";
    }
}