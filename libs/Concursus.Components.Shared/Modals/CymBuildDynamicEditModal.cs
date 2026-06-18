using System;
using System.Collections.Generic;
using System.Text;

namespace Concursus.Components.Shared.Modals;

public sealed class CymBuildDynamicEditModal
{
    public required Guid RecordGuid { get; init; }
    public required Guid EntityTypeGuid { get; init; }
    public required string Title { get; init; }
    public bool IsInformationPage { get; init; }
    public bool IsMainRecordContext { get; init; } = true;
    public string SizeCssClass { get; init; } = "cb-v2-modal-lg";
}
