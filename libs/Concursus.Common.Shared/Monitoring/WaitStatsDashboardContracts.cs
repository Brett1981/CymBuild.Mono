namespace Concursus.Common.Shared.Monitoring
{
    public sealed class WaitStatsDashboardQuery
    {
        public int TopCount { get; set; } = 15;
        public decimal CpuPressureSignalThresholdPct { get; set; } = 25.00m;
    }

    public sealed class WaitStatsDashboardResult
    {
        public WaitStatsDashboardSummaryDto Summary { get; set; } = new();
        public List<WaitCategoryDistributionDto> Categories { get; set; } = new();
        public List<TopWaitTypeDto> TopWaits { get; set; } = new();
        public List<ActiveWaitDto> ActiveWaits { get; set; } = new();
        public SignalResourceWaitSummaryDto SignalResourceSummary { get; set; } = new();
        public List<WaitRecommendationDto> Recommendations { get; set; } = new();
    }

    public sealed class WaitStatsDashboardSummaryDto
    {
        public DateTime SnapshotUtc { get; set; }
        public string DatabaseName { get; set; } = string.Empty;
        public string ServerName { get; set; } = string.Empty;
        public DateTime SqlServerStartTime { get; set; }
        public int SecondsSinceRestart { get; set; }
        public long TotalWaitTimeMs { get; set; }
        public decimal TotalWaitTimeSeconds { get; set; }
        public long TotalSignalWaitTimeMs { get; set; }
        public decimal TotalSignalWaitTimeSeconds { get; set; }
        public long TotalResourceWaitTimeMs { get; set; }
        public decimal TotalResourceWaitTimeSeconds { get; set; }
        public decimal SignalWaitPct { get; set; }
        public decimal ResourceWaitPct { get; set; }
        public bool IsCpuPressureHighlighted { get; set; }
        public string CpuPressureMessage { get; set; } = string.Empty;
    }

    public sealed class WaitCategoryDistributionDto
    {
        public string WaitCategory { get; set; } = string.Empty;
        public long WaitTimeMs { get; set; }
        public decimal WaitTimeSeconds { get; set; }
        public long SignalWaitTimeMs { get; set; }
        public long ResourceWaitTimeMs { get; set; }
        public long WaitingTasksCount { get; set; }
        public decimal PctOfTotalWaitTime { get; set; }
    }

    public sealed class TopWaitTypeDto
    {
        public string WaitType { get; set; } = string.Empty;
        public string WaitCategory { get; set; } = string.Empty;
        public long WaitingTasksCount { get; set; }
        public long WaitTimeMs { get; set; }
        public decimal WaitTimeSeconds { get; set; }
        public long SignalWaitTimeMs { get; set; }
        public decimal SignalWaitSeconds { get; set; }
        public long ResourceWaitTimeMs { get; set; }
        public decimal ResourceWaitSeconds { get; set; }
        public long MaxWaitTimeMs { get; set; }
        public decimal AvgWaitMsPerTask { get; set; }
        public decimal PctOfTotalWaitTime { get; set; }
        public decimal PctSignalWithinWait { get; set; }
    }

    public sealed class ActiveWaitDto
    {
        public DateTime SnapshotUtc { get; set; }
        public int SessionId { get; set; }
        public int RequestId { get; set; }
        public string Status { get; set; } = string.Empty;
        public string Command { get; set; } = string.Empty;
        public string? WaitType { get; set; }
        public long CurrentWaitMs { get; set; }
        public string? LastWaitType { get; set; }
        public string? WaitResource { get; set; }
        public int? BlockingSessionId { get; set; }
        public long CpuTimeMs { get; set; }
        public long TotalElapsedTimeMs { get; set; }
        public long Reads { get; set; }
        public long Writes { get; set; }
        public long LogicalReads { get; set; }
        public long GrantedQueryMemory { get; set; }
        public int? Dop { get; set; }
        public int? ParallelWorkerCount { get; set; }
        public string DatabaseName { get; set; } = string.Empty;
        public string? HostName { get; set; }
        public string? ProgramName { get; set; }
        public string? LoginName { get; set; }
        public string? RunningStatement { get; set; }
        public string? BatchText { get; set; }
    }

    public sealed class SignalResourceWaitSummaryDto
    {
        public long TotalWaitTimeMs { get; set; }
        public long SignalWaitTimeMs { get; set; }
        public long ResourceWaitTimeMs { get; set; }
        public decimal SignalWaitPct { get; set; }
        public decimal ResourceWaitPct { get; set; }
        public string SignalWaitAssessment { get; set; } = string.Empty;
    }

    public sealed class WaitRecommendationDto
    {
        public int Priority { get; set; }
        public string Pattern { get; set; } = string.Empty;
        public string Recommendation { get; set; } = string.Empty;
        public string SupportingMetric { get; set; } = string.Empty;
    }
}
