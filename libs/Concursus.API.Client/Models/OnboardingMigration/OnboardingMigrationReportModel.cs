namespace Concursus.API.Client.Models.OnboardingMigration;

public sealed class OnboardingMigrationReportModel
{
    public Guid RunGuid { get; set; }
    public string SourceDatabase { get; set; } = string.Empty;
    public string SourceServerName { get; set; } = string.Empty;
    public string TargetServerName { get; set; } = string.Empty;
    public string TargetDatabaseName { get; set; } = string.Empty;
    public Guid SourceBusinessUnitGroupGuid { get; set; }
    public string Notes { get; set; } = string.Empty;
    public string CreatedUtcText { get; set; } = string.Empty;
    public string CreatedBy { get; set; } = string.Empty;
    public List<OnboardingMigrationEntityCountModel> StagedCounts { get; set; } = new();
    public List<OnboardingMigrationValidationIssueModel> ValidationIssues { get; set; } = new();
    public List<OnboardingMigrationExecutionLogItemModel> ExecutionLog { get; set; } = new();
}