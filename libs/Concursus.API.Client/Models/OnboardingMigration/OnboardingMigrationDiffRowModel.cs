namespace Concursus.API.Client.Models.OnboardingMigration;

public sealed class OnboardingMigrationDiffRowModel
{
    public string EntityName { get; set; } = string.Empty;
    public Guid RowGuid { get; set; }
    public string DiffType { get; set; } = string.Empty;
    public Dictionary<string, string> SourceValues { get; set; } = new();
    public Dictionary<string, string> TargetValues { get; set; } = new();
    public List<string> DifferingColumns { get; set; } = new();
}