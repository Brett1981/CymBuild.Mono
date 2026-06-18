namespace Concursus.API.Client.Models.OnboardingMigration;

public sealed class OnboardingMigrationLookupItemModel
{
    public Guid Guid { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
}