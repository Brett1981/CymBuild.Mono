#nullable enable

using System.ComponentModel.DataAnnotations;

namespace Concursus.API.Services.Finance
{
    public sealed class SageInboundPaymentSyncWorkerOptions
    {
        public bool Enabled { get; set; } = true;

        [Range(1, 3600)]
        public int IntervalSeconds { get; set; } = 60;

        [Range(1, 1000)]
        public int BatchSize { get; set; } = 20;

        [Range(1, 1440)]
        public int ClaimStaleAfterMinutes { get; set; } = 30;
    }
}