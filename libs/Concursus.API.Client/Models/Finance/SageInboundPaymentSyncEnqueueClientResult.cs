namespace Concursus.API.Client.Models.Finance
{
    public sealed class SageInboundPaymentSyncEnqueueClientResult
    {
        public Guid CymBuildDocumentGuid { get; set; }

        public bool IsSuccess { get; set; }

        public string Message { get; set; } = string.Empty;
    }
}