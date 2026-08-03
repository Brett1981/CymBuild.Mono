namespace Concursus.API.Client.Models.OnboardingMigration;

public sealed class OnboardingMigrationEntitySelectionModel
{
    public Guid EntityScopeGuid { get; set; }
    public Guid SelectionGuid { get; set; }
    public string EntityCode { get; set; } = string.Empty;
    public string EntityName { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string StageTableName { get; set; } = string.Empty;
    public string ScopeCategory { get; set; } = string.Empty;
    public string ScopeType { get; set; } = string.Empty;
    public bool IsImplemented { get; set; }
    public bool IsSupportData { get; set; }
    public string HandlerKey { get; set; } = string.Empty;
    public Guid? PrimaryEntityTypeGuid { get; set; }
    public string SourceSchemaName { get; set; } = string.Empty;
    public string SourceTableName { get; set; } = string.Empty;
    public int DisplayOrder { get; set; }
    public bool IsSelected { get; set; }
    public bool DefaultSelected { get; set; }
    public bool CanDeselect { get; set; }
    public bool IsRequired { get; set; }
    public string RequiredDependencyCodes { get; set; } = string.Empty;
    public string SelectionSource { get; set; } = string.Empty;
    public string SelectedOnUtc { get; set; } = string.Empty;

    public IReadOnlyList<string> RequiredDependencies =>
        RequiredDependencyCodes
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .ToList();
}
