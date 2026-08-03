namespace Concursus.API.Client.Models.OnboardingMigration;

public sealed class OnboardingMigrationStageSelectionModel
{
    public string EntityName { get; set; } = string.Empty;
    public Guid RowGuid { get; set; }
    public string SelectedOnUtcText { get; set; } = string.Empty;
}
