using System.Text.Json.Serialization;

namespace Concursus.EF.MetadataManifests.ValidateOnly.ManifestModels;

/// <summary>
/// Grid family manifest v1 (SPEC-aligned).
/// - Designed to be "partial": only fields provided in the manifest are validated.
/// - Stable key is Guid; Code is included for readability and optional validation.
/// </summary>
public sealed class GridFamilyManifestV1
{
    [JsonPropertyName("manifestVersion")]
    public string ManifestVersion { get; set; } = "v1";

    [JsonPropertyName("family")]
    public string Family { get; set; } = "grids";

    [JsonPropertyName("generatedAtUtc")]
    public DateTime? GeneratedAtUtc { get; set; }

    [JsonPropertyName("grids")]
    public List<GridDefinitionV1> Grids { get; set; } = new();
}

/// <summary>
/// Represents SUserInterface.GridDefinitions (plus nested children).
/// </summary>
public sealed class GridDefinitionV1
{
    [JsonPropertyName("guid")]
    public Guid Guid { get; set; }

    /// <summary>Human stable code (secondary; not used as match key).</summary>
    [JsonPropertyName("code")]
    public string? Code { get; set; }

    /// <summary>RowStatus (0 New, 1 Active, 254 Deleted, etc). If null, validator does not check it.</summary>
    [JsonPropertyName("rowStatus")]
    public int? RowStatus { get; set; }

    [JsonPropertyName("pageUri")]
    public string? PageUri { get; set; }

    [JsonPropertyName("tabName")]
    public string? TabName { get; set; }

    [JsonPropertyName("showAsTiles")]
    public bool? ShowAsTiles { get; set; }

    /// <summary>
    /// LanguageLabelId is an INT FK in DB, but the manifest references by stable key.
    /// </summary>
    [JsonPropertyName("languageLabel")]
    public RefV1? LanguageLabel { get; set; }

    [JsonPropertyName("views")]
    public List<GridViewDefinitionV1> Views { get; set; } = new();
}

/// <summary>
/// Represents SUserInterface.GridViewDefinitions.
/// Only validates properties that are supplied in the manifest.
/// </summary>
public sealed class GridViewDefinitionV1
{
    [JsonPropertyName("guid")]
    public Guid Guid { get; set; }

    [JsonPropertyName("code")]
    public string? Code { get; set; }

    [JsonPropertyName("rowStatus")]
    public int? RowStatus { get; set; }

    [JsonPropertyName("detailPageUri")]
    public string? DetailPageUri { get; set; }

    [JsonPropertyName("sqlQuery")]
    public string? SqlQuery { get; set; }

    [JsonPropertyName("defaultSortColumnName")]
    public string? DefaultSortColumnName { get; set; }

    [JsonPropertyName("isDefaultSortDescending")]
    public bool? IsDefaultSortDescending { get; set; }

    [JsonPropertyName("securableCode")]
    public string? SecurableCode { get; set; }

    [JsonPropertyName("displayOrder")]
    public int? DisplayOrder { get; set; }

    [JsonPropertyName("displayGroupName")]
    public string? DisplayGroupName { get; set; }

    [JsonPropertyName("showOnMobile")]
    public bool? ShowOnMobile { get; set; }

    [JsonPropertyName("showOnDashboard")]
    public bool? ShowOnDashboard { get; set; }

    [JsonPropertyName("allowNew")]
    public bool? AllowNew { get; set; }

    [JsonPropertyName("allowExcelExport")]
    public bool? AllowExcelExport { get; set; }

    [JsonPropertyName("allowPdfExport")]
    public bool? AllowPdfExport { get; set; }

    [JsonPropertyName("allowCsvExport")]
    public bool? AllowCsvExport { get; set; }

    [JsonPropertyName("allowBulkChange")]
    public bool? AllowBulkChange { get; set; }

    [JsonPropertyName("isDetailWindowed")]
    public bool? IsDetailWindowed { get; set; }

    // External prerequisites
    [JsonPropertyName("entityType")]
    public RefV1? EntityType { get; set; }

    [JsonPropertyName("gridViewType")]
    public RefV1? GridViewType { get; set; }

    [JsonPropertyName("drawerIcon")]
    public RefV1? DrawerIcon { get; set; }

    [JsonPropertyName("languageLabel")]
    public RefV1? LanguageLabel { get; set; }

    [JsonPropertyName("metricType")]
    public RefV1? MetricType { get; set; }

    // --------------------------------------------------------------------
    // Stage 2 – Task 2.2 (Governance lock):
    // Optional arrays where NULL/ABSENT means "not managed yet".
    //
    // IMPORTANT:
    // - If the JSON omits "columns" / "actions" / "widgets", these properties remain null.
    // - If the JSON includes "columns": [], that is an explicit empty-managed set.
    // - Downstream validation (Task 2.3) will apply the "null = not managed" rules.
    // --------------------------------------------------------------------

    [JsonPropertyName("columns")]
    public List<GridViewColumnDefinitionV1>? Columns { get; set; }

    [JsonPropertyName("actions")]
    public List<GridViewActionV1>? Actions { get; set; }

    [JsonPropertyName("widgets")]
    public List<GridViewWidgetQueryV1>? Widgets { get; set; }
}

/// <summary>
/// Represents SUserInterface.GridViewColumnDefinitions.
/// </summary>
public sealed class GridViewColumnDefinitionV1
{
    [JsonPropertyName("guid")]
    public Guid Guid { get; set; }

    [JsonPropertyName("rowStatus")]
    public int? RowStatus { get; set; }

    [JsonPropertyName("name")]
    public string? Name { get; set; }

    [JsonPropertyName("columnOrder")]
    public int? ColumnOrder { get; set; }

    [JsonPropertyName("isPrimaryKey")]
    public bool? IsPrimaryKey { get; set; }

    [JsonPropertyName("isHidden")]
    public bool? IsHidden { get; set; }

    [JsonPropertyName("isFiltered")]
    public bool? IsFiltered { get; set; }

    [JsonPropertyName("displayFormat")]
    public string? DisplayFormat { get; set; }

    [JsonPropertyName("width")]
    public string? Width { get; set; }

    [JsonPropertyName("topHeaderCategory")]
    public string? TopHeaderCategory { get; set; }

    [JsonPropertyName("topHeaderCategoryOrder")]
    public int? TopHeaderCategoryOrder { get; set; }

    [JsonPropertyName("languageLabel")]
    public RefV1? LanguageLabel { get; set; }
}

/// <summary>
/// Represents SUserInterface.GridViewActions.
/// </summary>
public sealed class GridViewActionV1
{
    [JsonPropertyName("guid")]
    public Guid Guid { get; set; }

    [JsonPropertyName("rowStatus")]
    public int? RowStatus { get; set; }

    [JsonPropertyName("languageLabel")]
    public RefV1? LanguageLabel { get; set; }

    [JsonPropertyName("entityQuery")]
    public RefV1? EntityQuery { get; set; }
}

/// <summary>
/// Represents SUserInterface.GridViewWidgetQueries.
/// </summary>
public sealed class GridViewWidgetQueryV1
{
    [JsonPropertyName("guid")]
    public Guid Guid { get; set; }

    [JsonPropertyName("rowStatus")]
    public int? RowStatus { get; set; }

    [JsonPropertyName("languageLabel")]
    public RefV1? LanguageLabel { get; set; }

    [JsonPropertyName("entityQuery")]
    public RefV1? EntityQuery { get; set; }

    [JsonPropertyName("widgetType")]
    public RefV1? WidgetType { get; set; }
}

/// <summary>
/// Stable reference to an external prerequisite row.
/// DB columns are typically INT IDs; this allows lookup by GUID or Name/Code.
/// </summary>
public sealed class RefV1
{
    /// <summary>e.g. "SCore.LanguageLabels"</summary>
    [JsonPropertyName("ref")]
    public string RefTable { get; set; } = string.Empty;

    /// <summary>"guid" | "name" | "code"</summary>
    [JsonPropertyName("key")]
    public string Key { get; set; } = "guid";

    /// <summary>Value for the key (Guid string or name/code)</summary>
    [JsonPropertyName("value")]
    public string Value { get; set; } = string.Empty;
}
