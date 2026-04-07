namespace CymBuild_AIErrorServiceAPI.Dto
{
    public class JiraSyncLogDto
    {
        public DateTime TimeStartedUtc { get; set; }
        public DateTime TimeEndedUtc { get; set; }
        public bool Success { get; set; }
        public string Message { get; set; }
    }
}