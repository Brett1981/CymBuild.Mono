using System.Text.Json.Serialization;

namespace Concursus.EF.MetadataManifests.ValidateOnly.Policies;

/// <summary>
/// Governance-locked: Stage 1 managed scope is an explicit allow-list of GridDefinition GUIDs.
/// This file is repo-controlled. It can start empty and be expanded deliberately.
/// </summary>
public sealed class GridAllowlist
{
    [JsonPropertyName("gridDefinitionGuids")]
    public List<Guid> GridDefinitionGuids { get; set; } = new();
}
