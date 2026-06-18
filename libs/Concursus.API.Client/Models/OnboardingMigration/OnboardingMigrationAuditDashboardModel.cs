namespace Concursus.API.Client.Models.OnboardingMigration;

public sealed class OnboardingMigrationAuditDashboardModel
{
    public int StagedEntityCount { get; set; }
    public int TotalStagedRows { get; set; }
    public int ValidationErrorCount { get; set; }
    public int ValidationWarningCount { get; set; }
    public int ExecutionLogCount { get; set; }
    public int InsertedRowCount { get; set; }
    public int UpdatedRowCount { get; set; }
    public List<OnboardingMigrationEntityCountModel> StagedCounts { get; set; } = new();
    public List<OnboardingMigrationValidationIssueModel> ValidationIssues { get; set; } = new();
    public List<OnboardingMigrationExecutionLogItemModel> ExecutionLog { get; set; } = new();
}