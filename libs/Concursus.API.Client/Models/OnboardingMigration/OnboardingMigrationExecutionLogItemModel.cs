namespace Concursus.API.Client.Models.OnboardingMigration;

public sealed class OnboardingMigrationExecutionLogItemModel
{
    public string StepName { get; set; } = string.Empty;
    public string EntityName { get; set; } = string.Empty;
    public string ActionName { get; set; } = string.Empty;
    public int AffectedCount { get; set; }
    public string Details { get; set; } = string.Empty;
    public string LoggedUtcText { get; set; } = string.Empty;
}