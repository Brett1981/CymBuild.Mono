using System.Text.Json.Serialization;

namespace Concursus.EF.MetadataManifests.ValidateOnly.Reporting;

/// <summary>
/// Severity is intentionally numeric and stable for CI.
/// </summary>
public enum DriftSeverity
{
    Info = 0,
    Warn = 1,
    Fail = 2
}

/// <summary>
/// Drift types are stable identifiers for CI/report consumers.
/// </summary>
public enum DriftType
{
    Missing = 0,
    Different = 1,
    UnresolvableReference = 2,
    UnexpectedUnmanagedRow = 3,
    InvalidManifest = 4
}

/// <summary>
/// ValidateOnly output contract.
///
/// Governance locks respected:
/// - Additive/backward compatible: Stage 1 fields remain unchanged; Stage 2 adds new sections.
/// - Deterministic: stable ordering for CI consumption.
/// - ValidateOnly: no DB writes.
/// </summary>
public sealed class ValidationReport
{
    // ---------------------------------------------------------------------
    // Stage 1 fields (LOCKED)
    // ---------------------------------------------------------------------

    [JsonPropertyName("runId")]
    public Guid RunId { get; set; } = Guid.NewGuid();

    [JsonPropertyName("environment")]
    public string Environment { get; set; } = "Unknown";

    [JsonPropertyName("family")]
    public string Family { get; set; } = "grids";

    [JsonPropertyName("manifestPath")]
    public string ManifestPath { get; set; } = string.Empty;

    [JsonPropertyName("allowlistPath")]
    public string AllowlistPath { get; set; } = string.Empty;

    [JsonPropertyName("startedAtUtc")]
    public DateTime StartedAtUtc { get; set; } = DateTime.UtcNow;

    [JsonPropertyName("completedAtUtc")]
    public DateTime CompletedAtUtc { get; set; }

    [JsonPropertyName("items")]
    public List<ValidationIssue> Items { get; set; } = new();

    [JsonPropertyName("summary")]
    public ValidationSummary Summary { get; set; } = new();

    // ---------------------------------------------------------------------
    // Stage 2 additive sections (Task 2.4)
    // ---------------------------------------------------------------------

    /// <summary>
    /// CI-friendly deterministic summary.
    /// Additive: Stage 1 consumers can ignore this.
    /// </summary>
    [JsonPropertyName("ciSummary")]
    public ValidationCiSummary CiSummary { get; set; } = new();

    /// <summary>
    /// Deterministic rollups per allow-listed GridViewDefinition.
    /// Derived from items[].details (gridGuid/viewGuid keys).
    /// </summary>
    [JsonPropertyName("viewSummaries")]
    public List<ViewValidationSummary> ViewSummaries { get; set; } = new();

    /// <summary>
    /// Optional Stage 2 section: counts of internals per view (Task 2.1).
    /// Keep existing model names to avoid repo churn.
    /// </summary>
    [JsonPropertyName("internalsCounts")]
    public InternalsCountsSection? InternalsCounts { get; set; }

    /// <summary>
    /// Optional Stage 2 section: internals validation per view (Task 2.3).
    /// Keep existing model names + nullable manifest counts to preserve semantics.
    /// </summary>
    [JsonPropertyName("internalsValidation")]
    public InternalsValidationSection? InternalsValidation { get; set; }

    public void FinalizeReport()
    {
        CompletedAtUtc = DateTime.UtcNow;

        Summary.FailCount = Items.Count(i => i.Severity == DriftSeverity.Fail);
        Summary.WarnCount = Items.Count(i => i.Severity == DriftSeverity.Warn);
        Summary.InfoCount = Items.Count(i => i.Severity == DriftSeverity.Info);

        // Deterministic ordering for CI stability.
        Summary.ByType = Items
            .GroupBy(i => i.Type)
            .OrderBy(g => g.Key.ToString(), StringComparer.Ordinal)
            .ToDictionary(g => g.Key.ToString(), g => g.Count(), StringComparer.Ordinal);

        // -------------------------------
        // CI summary (Task 2.4 additive)
        // -------------------------------
        CiSummary.Environment = Environment;
        CiSummary.Family = Family;
        CiSummary.ExitCode = GetExitCode();

        CiSummary.FailCount = Summary.FailCount;
        CiSummary.WarnCount = Summary.WarnCount;
        CiSummary.InfoCount = Summary.InfoCount;

        CiSummary.HasFailures = Summary.FailCount > 0;
        CiSummary.HasWarnings = Summary.WarnCount > 0;
        CiSummary.HasInfo = Summary.InfoCount > 0;

        CiSummary.ByType = new Dictionary<string, int>(Summary.ByType, StringComparer.Ordinal);

        CiSummary.ByTable = Items
            .GroupBy(i => i.Table ?? string.Empty)
            .OrderBy(g => g.Key, StringComparer.Ordinal)
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.Ordinal);

        // Only populated if issues include details["internals"] (columns/actions/widgets).
        CiSummary.ByInternalsKind = Items
            .Select(i => TryGet(i.Details, "internals"))
            .Where(k => !string.IsNullOrWhiteSpace(k))
            .GroupBy(k => k!, StringComparer.Ordinal)
            .OrderBy(g => g.Key, StringComparer.Ordinal)
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.Ordinal);

        // ----------------------------------
        // Per-view rollups (Task 2.4 additive)
        // ----------------------------------
        ViewSummaries = BuildViewSummaries(Items);

        // If internals sections are present, keep deterministic ordering.
        if (InternalsCounts is not null)
        {
            InternalsCounts.Views = InternalsCounts.Views
                .OrderBy(v => v.GridGuid)
                .ThenBy(v => v.ViewGuid)
                .ToList();
        }

        if (InternalsValidation is not null)
        {
            InternalsValidation.Views = InternalsValidation.Views
                .OrderBy(v => v.GridGuid)
                .ThenBy(v => v.ViewGuid)
                .ToList();
        }
    }

    public int GetExitCode()
    {
        // Governance: any FAIL means the run is a failure.
        return Summary.FailCount > 0 ? 2 : 0;
    }

    private static List<ViewValidationSummary> BuildViewSummaries(IReadOnlyList<ValidationIssue> items)
    {
        // Derived from stage 2 standard details keys.
        // Items that lack these keys are excluded from the rollups.
        var groups = items
            .Select(i => new
            {
                Issue = i,
                GridGuid = TryGetGuid(i.Details, "gridGuid"),
                GridCode = TryGet(i.Details, "gridCode"),
                ViewGuid = TryGetGuid(i.Details, "viewGuid"),
                ViewCode = TryGet(i.Details, "viewCode"),
                InternalsKind = TryGet(i.Details, "internals")
            })
            .Where(x => x.GridGuid.HasValue && x.ViewGuid.HasValue)
            .GroupBy(x => new { x.GridGuid, x.GridCode, x.ViewGuid, x.ViewCode }, (k, rows) => new { k, rows = rows.ToList() });

        var result = new List<ViewValidationSummary>();

        foreach (var g in groups
                     .OrderBy(x => x.k.GridGuid)
                     .ThenBy(x => x.k.ViewGuid))
        {
            var all = g.rows.Select(r => r.Issue).ToList();

            var bySeverity = all
                .GroupBy(i => i.Severity)
                .OrderBy(s => (int)s.Key)
                .ToDictionary(s => s.Key.ToString(), s => s.Count(), StringComparer.Ordinal);

            var byType = all
                .GroupBy(i => i.Type)
                .OrderBy(t => t.Key.ToString(), StringComparer.Ordinal)
                .ToDictionary(t => t.Key.ToString(), t => t.Count(), StringComparer.Ordinal);

            var byInternals = g.rows
                .Select(r => r.InternalsKind)
                .Where(k => !string.IsNullOrWhiteSpace(k))
                .GroupBy(k => k!, StringComparer.Ordinal)
                .OrderBy(x => x.Key, StringComparer.Ordinal)
                .ToDictionary(x => x.Key, x => x.Count(), StringComparer.Ordinal);

            result.Add(new ViewValidationSummary
            {
                GridGuid = g.k.GridGuid!.Value,
                GridCode = g.k.GridCode ?? string.Empty,
                ViewGuid = g.k.ViewGuid!.Value,
                ViewCode = g.k.ViewCode ?? string.Empty,
                FailCount = all.Count(i => i.Severity == DriftSeverity.Fail),
                WarnCount = all.Count(i => i.Severity == DriftSeverity.Warn),
                InfoCount = all.Count(i => i.Severity == DriftSeverity.Info),
                BySeverity = bySeverity,
                ByType = byType,
                ByInternalsKind = byInternals
            });
        }

        return result;
    }

    private static string? TryGet(Dictionary<string, string>? d, string key)
        => d is not null && d.TryGetValue(key, out var v) ? v : null;

    private static Guid? TryGetGuid(Dictionary<string, string>? d, string key)
    {
        var s = TryGet(d, key);
        return Guid.TryParse(s, out var g) ? g : null;
    }
}

public sealed class ValidationSummary
{
    [JsonPropertyName("failCount")]
    public int FailCount { get; set; }

    [JsonPropertyName("warnCount")]
    public int WarnCount { get; set; }

    [JsonPropertyName("infoCount")]
    public int InfoCount { get; set; }

    [JsonPropertyName("byType")]
    public Dictionary<string, int> ByType { get; set; } = new(StringComparer.Ordinal);
}

public sealed class ValidationIssue
{
    [JsonPropertyName("severity")]
    public DriftSeverity Severity { get; set; }

    [JsonPropertyName("type")]
    public DriftType Type { get; set; }

    [JsonPropertyName("table")]
    public string Table { get; set; } = string.Empty;

    [JsonPropertyName("recordGuid")]
    public Guid? RecordGuid { get; set; }

    [JsonPropertyName("message")]
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// Optional details; these are used for per-view rollups in Task 2.4.
    /// </summary>
    [JsonPropertyName("details")]
    public Dictionary<string, string>? Details { get; set; }
}

// -------------------------------------------------------------------------
// Task 2.4 additive models
// -------------------------------------------------------------------------

public sealed class ValidationCiSummary
{
    [JsonPropertyName("environment")]
    public string Environment { get; set; } = "Unknown";

    [JsonPropertyName("family")]
    public string Family { get; set; } = "grids";

    [JsonPropertyName("exitCode")]
    public int ExitCode { get; set; }

    [JsonPropertyName("hasFailures")]
    public bool HasFailures { get; set; }

    [JsonPropertyName("hasWarnings")]
    public bool HasWarnings { get; set; }

    [JsonPropertyName("hasInfo")]
    public bool HasInfo { get; set; }

    [JsonPropertyName("failCount")]
    public int FailCount { get; set; }

    [JsonPropertyName("warnCount")]
    public int WarnCount { get; set; }

    [JsonPropertyName("infoCount")]
    public int InfoCount { get; set; }

    [JsonPropertyName("byType")]
    public Dictionary<string, int> ByType { get; set; } = new(StringComparer.Ordinal);

    [JsonPropertyName("byTable")]
    public Dictionary<string, int> ByTable { get; set; } = new(StringComparer.Ordinal);

    [JsonPropertyName("byInternalsKind")]
    public Dictionary<string, int> ByInternalsKind { get; set; } = new(StringComparer.Ordinal);
}

public sealed class ViewValidationSummary
{
    [JsonPropertyName("gridGuid")]
    public Guid GridGuid { get; set; }

    [JsonPropertyName("gridCode")]
    public string GridCode { get; set; } = string.Empty;

    [JsonPropertyName("viewGuid")]
    public Guid ViewGuid { get; set; }

    [JsonPropertyName("viewCode")]
    public string ViewCode { get; set; } = string.Empty;

    [JsonPropertyName("failCount")]
    public int FailCount { get; set; }

    [JsonPropertyName("warnCount")]
    public int WarnCount { get; set; }

    [JsonPropertyName("infoCount")]
    public int InfoCount { get; set; }

    [JsonPropertyName("bySeverity")]
    public Dictionary<string, int> BySeverity { get; set; } = new(StringComparer.Ordinal);

    [JsonPropertyName("byType")]
    public Dictionary<string, int> ByType { get; set; } = new(StringComparer.Ordinal);

    [JsonPropertyName("byInternalsKind")]
    public Dictionary<string, int> ByInternalsKind { get; set; } = new(StringComparer.Ordinal);
}

// -------------------------------------------------------------------------
// Existing Stage 2 model names (preserved to avoid repo churn)
// -------------------------------------------------------------------------

public sealed class InternalsCountsSection
{
    [JsonPropertyName("enabled")]
    public bool Enabled { get; set; }

    [JsonPropertyName("views")]
    public List<ViewInternalsCount> Views { get; set; } = new();
}

public sealed class ViewInternalsCount
{
    [JsonPropertyName("gridGuid")]
    public Guid GridGuid { get; set; }

    [JsonPropertyName("gridCode")]
    public string GridCode { get; set; } = string.Empty;

    [JsonPropertyName("viewGuid")]
    public Guid ViewGuid { get; set; }

    [JsonPropertyName("viewCode")]
    public string ViewCode { get; set; } = string.Empty;

    [JsonPropertyName("columnCount")]
    public int ColumnCount { get; set; }

    [JsonPropertyName("actionCount")]
    public int ActionCount { get; set; }

    [JsonPropertyName("widgetCount")]
    public int WidgetCount { get; set; }
}

public sealed class InternalsValidationSection
{
    [JsonPropertyName("enabled")]
    public bool Enabled { get; set; }

    [JsonPropertyName("views")]
    public List<ViewInternalsValidation> Views { get; set; } = new();

    [JsonPropertyName("summary")]
    public InternalsValidationSummary Summary { get; set; } = new();
}

public sealed class ViewInternalsValidation
{
    [JsonPropertyName("gridGuid")]
    public Guid GridGuid { get; set; }

    [JsonPropertyName("gridCode")]
    public string GridCode { get; set; } = string.Empty;

    [JsonPropertyName("viewGuid")]
    public Guid ViewGuid { get; set; }

    [JsonPropertyName("viewCode")]
    public string ViewCode { get; set; } = string.Empty;

    [JsonPropertyName("columnsManaged")]
    public bool ColumnsManaged { get; set; }

    [JsonPropertyName("actionsManaged")]
    public bool ActionsManaged { get; set; }

    [JsonPropertyName("widgetsManaged")]
    public bool WidgetsManaged { get; set; }

    [JsonPropertyName("dbColumnCount")]
    public int DbColumnCount { get; set; }

    [JsonPropertyName("dbActionCount")]
    public int DbActionCount { get; set; }

    [JsonPropertyName("dbWidgetCount")]
    public int DbWidgetCount { get; set; }

    // IMPORTANT (governance): keep nullable so "not managed" stays distinguishable from 0.

    [JsonPropertyName("manifestColumnCount")]
    public int? ManifestColumnCount { get; set; }

    [JsonPropertyName("manifestActionCount")]
    public int? ManifestActionCount { get; set; }

    [JsonPropertyName("manifestWidgetCount")]
    public int? ManifestWidgetCount { get; set; }
}

public sealed class InternalsValidationSummary
{
    [JsonPropertyName("failCount")]
    public int FailCount { get; set; }

    [JsonPropertyName("warnCount")]
    public int WarnCount { get; set; }

    [JsonPropertyName("infoCount")]
    public int InfoCount { get; set; }
}
