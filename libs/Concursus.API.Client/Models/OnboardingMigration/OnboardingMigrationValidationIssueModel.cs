namespace Concursus.API.Client.Models.OnboardingMigration;

public sealed class OnboardingMigrationValidationIssueModel
{
    public string EntityName { get; set; } = string.Empty;
    public string StageTable { get; set; } = string.Empty;
    public Guid StageGuid { get; set; }
    public string Severity { get; set; } = string.Empty;
    public string IssueCode { get; set; } = string.Empty;
    public string IssueMessage { get; set; } = string.Empty;
}