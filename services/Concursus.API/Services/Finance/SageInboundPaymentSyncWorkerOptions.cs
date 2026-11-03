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
        public int ClaimStaleAfterMinutes { get; set; } = 15;

        /// <summary>
        /// CYB-555: when a settled invoice is synced, ask the wrapper's
        /// /api/v2/sales-allocations what settled it, and record a Receipt or
        /// Credit Note from the answer, or "settled, method unknown" when Sage
        /// cannot say. On by default (the wrapper is deployed before CymBuild).
        /// Setting it to false is the emergency fallback: a settled invoice is
        /// then recorded as a Receipt again (CYB-568).
        /// </summary>
        public bool UseSalesAllocations { get; set; } = true;
    }
}