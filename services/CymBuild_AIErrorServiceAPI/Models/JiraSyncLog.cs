namespace CymBuild_AIErrorServiceAPI.Models
{
    public class JiraSyncLog
    {
        public int Id { get; set; }
        public DateTime StartedUtc { get; set; }
        public DateTime EndedUtc { get; set; }
        public bool Success { get; set; }
        public string Message { get; set; } = "";
    }
}