namespace Concursus.API.Client.Models.OnboardingMigration;

public sealed class OnboardingMigrationStagedRowModel
{
    public string EntityName { get; set; } = string.Empty;
    public Guid RowGuid { get; set; }
    public Dictionary<string, string> Values { get; set; } = new();
}