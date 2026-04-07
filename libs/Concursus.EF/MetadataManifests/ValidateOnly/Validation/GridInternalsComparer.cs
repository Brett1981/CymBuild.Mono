using Concursus.EF.MetadataManifests.ValidateOnly.ManifestModels;
using Concursus.EF.MetadataManifests.ValidateOnly.Reporting;
using Concursus.EF.MetadataManifests.ValidateOnly.Sql;

namespace Concursus.EF.MetadataManifests.ValidateOnly.Validation;

/// <summary>
/// Pure deterministic comparison engine for grid internals (Stage 2 – Task 2.3/2.5).
///
/// - Matching priority: GUID first (always for these internals).
/// - Optional diffs: only compare fields that are present in the manifest.
/// - "Not managed yet" behaviour:
///     If manifest array is null/absent => do not emit MissingInDb.
///     Unmanaged rows become INFO only by default (gentle adoption).
/// - "Different" is always FAIL (all environments) — locked governance decision.
/// - Unmanaged drift severity defaults:
///     QA/UAT WARN; Live/Prod INFO.
/// - Task 2.5: Add *optional* severity knobs (defaults preserve locked behaviour).
/// </summary>
public static class GridInternalsComparer
{
    /// <summary>
    /// Stage 2 – Task 2.5: optional severity knobs for unmanaged drift.
    /// Defaults are aligned to governance locks and preserve current behaviour.
    /// </summary>
    public readonly record struct GridInternalsSeverityKnobs(
        DriftSeverity QaUnmanaged,
        DriftSeverity UatUnmanaged,
        DriftSeverity LiveUnmanaged,
        DriftSeverity NotManagedYetUnmanaged)
    {
        public static GridInternalsSeverityKnobs Default => new(
            QaUnmanaged: DriftSeverity.Warn,
            UatUnmanaged: DriftSeverity.Warn,
            LiveUnmanaged: DriftSeverity.Info,
            NotManagedYetUnmanaged: DriftSeverity.Info);

        public DriftSeverity ResolveUnmanaged(string environment)
        {
            if (environment.Equals("UAT", StringComparison.OrdinalIgnoreCase))
                return UatUnmanaged;

            if (environment.Equals("QA", StringComparison.OrdinalIgnoreCase))
                return QaUnmanaged;

            // Treat LIVE/PROD as Live severity by default (locked decision).
            if (environment.Equals("LIVE", StringComparison.OrdinalIgnoreCase) ||
                environment.Equals("PROD", StringComparison.OrdinalIgnoreCase))
                return LiveUnmanaged;

            // Default fallback for other environments: align with QA behaviour.
            return QaUnmanaged;
        }
    }

    public static DriftSeverity GetUnmanagedSeverity(string environment, GridInternalsSeverityKnobs knobs)
        => knobs.ResolveUnmanaged(environment);

    public static DriftSeverity GetUnmanagedSeverityWhenNotManagedYet(GridInternalsSeverityKnobs knobs)
        => knobs.NotManagedYetUnmanaged;

    public static List<ValidationIssue> CompareColumns(
        string environment,
        GridInternalsSeverityKnobs knobs,
        Guid gridGuid,
        string gridCode,
        Guid viewGuid,
        string viewCode,
        IReadOnlyList<GridViewColumnDefinitionV1>? manifestColumns,
        IReadOnlyList<GridViewColumnRow> dbColumns,
        IReadOnlyDictionary<Guid, int> languageLabelGuidToId)
    {
        var issues = new List<ValidationIssue>();

        // Null/absent array => not managed yet
        if (manifestColumns is null)
        {
            // Gentle adoption: unmanaged rows are INFO only (default), but knobbed for future.
            foreach (var db in dbColumns.OrderBy(x => x.Guid))
            {
                issues.Add(new ValidationIssue
                {
                    Severity = GetUnmanagedSeverityWhenNotManagedYet(knobs),
                    Type = DriftType.UnexpectedUnmanagedRow,
                    Table = "SUserInterface.GridViewColumnDefinitions",
                    RecordGuid = db.Guid,
                    Message = "DB column exists but columns[] is not managed by manifest (null/absent).",
                    Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "columns")
                });
            }

            return issues;
        }

        var manifestByGuid = manifestColumns.ToDictionary(x => x.Guid, x => x);
        var dbByGuid = dbColumns.ToDictionary(x => x.Guid, x => x);

        // MissingInDb (only when managed)
        foreach (var m in manifestColumns.OrderBy(x => x.Guid))
        {
            if (!dbByGuid.ContainsKey(m.Guid))
            {
                issues.Add(new ValidationIssue
                {
                    Severity = DriftSeverity.Fail,
                    Type = DriftType.Missing,
                    Table = "SUserInterface.GridViewColumnDefinitions",
                    RecordGuid = m.Guid,
                    Message = "Manifest column GUID does not exist in DB.",
                    Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "columns")
                });
            }
        }

        // UnmanagedInDb (only when managed)
        var unmanagedSeverity = GetUnmanagedSeverity(environment, knobs);

        foreach (var db in dbColumns.OrderBy(x => x.Guid))
        {
            if (!manifestByGuid.ContainsKey(db.Guid))
            {
                issues.Add(new ValidationIssue
                {
                    Severity = unmanagedSeverity,
                    Type = DriftType.UnexpectedUnmanagedRow,
                    Table = "SUserInterface.GridViewColumnDefinitions",
                    RecordGuid = db.Guid,
                    Message = "DB column exists but is not represented in manifest columns[].",
                    Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "columns")
                });
            }
        }

        // Optional diffs (only where manifest provides the property)
        foreach (var m in manifestColumns.OrderBy(x => x.Guid))
        {
            if (!dbByGuid.TryGetValue(m.Guid, out var db))
                continue;

            // Different => FAIL (locked)
            CompareIntIfPresent(issues, "SUserInterface.GridViewColumnDefinitions", m.Guid,
                "RowStatus", m.RowStatus, db.RowStatus, gridGuid, gridCode, viewGuid, viewCode, "columns");

            CompareStringIfPresent(issues, "SUserInterface.GridViewColumnDefinitions", m.Guid,
                "Name", m.Name, db.Name, gridGuid, gridCode, viewGuid, viewCode, "columns");

            CompareIntIfPresent(issues, "SUserInterface.GridViewColumnDefinitions", m.Guid,
                "ColumnOrder", m.ColumnOrder, db.ColumnOrder, gridGuid, gridCode, viewGuid, viewCode, "columns");

            CompareBoolIfPresent(issues, "SUserInterface.GridViewColumnDefinitions", m.Guid,
                "IsPrimaryKey", m.IsPrimaryKey, db.IsPrimaryKey, gridGuid, gridCode, viewGuid, viewCode, "columns");

            CompareBoolIfPresent(issues, "SUserInterface.GridViewColumnDefinitions", m.Guid,
                "IsHidden", m.IsHidden, db.IsHidden, gridGuid, gridCode, viewGuid, viewCode, "columns");

            CompareBoolIfPresent(issues, "SUserInterface.GridViewColumnDefinitions", m.Guid,
                "IsFiltered", m.IsFiltered, db.IsFiltered, gridGuid, gridCode, viewGuid, viewCode, "columns");

            CompareStringIfPresent(issues, "SUserInterface.GridViewColumnDefinitions", m.Guid,
                "DisplayFormat", m.DisplayFormat, db.DisplayFormat, gridGuid, gridCode, viewGuid, viewCode, "columns");

            CompareStringIfPresent(issues, "SUserInterface.GridViewColumnDefinitions", m.Guid,
                "Width", m.Width, db.Width, gridGuid, gridCode, viewGuid, viewCode, "columns");

            CompareStringIfPresent(issues, "SUserInterface.GridViewColumnDefinitions", m.Guid,
                "TopHeaderCategory", m.TopHeaderCategory, db.TopHeaderCategory, gridGuid, gridCode, viewGuid, viewCode, "columns");

            CompareIntIfPresent(issues, "SUserInterface.GridViewColumnDefinitions", m.Guid,
                "TopHeaderCategoryOrder", m.TopHeaderCategoryOrder, db.TopHeaderCategoryOrder, gridGuid, gridCode, viewGuid, viewCode, "columns");

            // LanguageLabelId via manifest reference
            if (m.LanguageLabel is not null)
            {
                if (!TryResolveGuidRef(m.LanguageLabel, "SCore.LanguageLabels", out var llGuid))
                {
                    issues.Add(new ValidationIssue
                    {
                        Severity = DriftSeverity.Fail,
                        Type = DriftType.UnresolvableReference,
                        Table = "SUserInterface.GridViewColumnDefinitions",
                        RecordGuid = m.Guid,
                        Message = "Column.languageLabel must be a guid reference to SCore.LanguageLabels.",
                        Details = MergeDetails(BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "columns"),
                            ("ref", m.LanguageLabel.RefTable), ("key", m.LanguageLabel.Key), ("value", m.LanguageLabel.Value))
                    });
                }
                else if (!languageLabelGuidToId.TryGetValue(llGuid, out var expectedId))
                {
                    issues.Add(new ValidationIssue
                    {
                        Severity = DriftSeverity.Fail,
                        Type = DriftType.UnresolvableReference,
                        Table = "SCore.LanguageLabels",
                        RecordGuid = llGuid,
                        Message = "Referenced LanguageLabel not found in DB.",
                        Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "columns")
                    });
                }
                else
                {
                    CompareIntExact(issues, "SUserInterface.GridViewColumnDefinitions", m.Guid,
                        "LanguageLabelId", expectedId, db.LanguageLabelId, gridGuid, gridCode, viewGuid, viewCode, "columns");
                }
            }
        }

        return issues;
    }

    public static List<ValidationIssue> CompareActions(
        string environment,
        GridInternalsSeverityKnobs knobs,
        Guid gridGuid,
        string gridCode,
        Guid viewGuid,
        string viewCode,
        IReadOnlyList<GridViewActionV1>? manifestActions,
        IReadOnlyList<GridViewActionRow> dbActions,
        IReadOnlyDictionary<Guid, int> languageLabelGuidToId,
        IReadOnlyDictionary<Guid, int> entityQueryGuidToId)
    {
        var issues = new List<ValidationIssue>();

        if (manifestActions is null)
        {
            foreach (var db in dbActions.OrderBy(x => x.Guid))
            {
                issues.Add(new ValidationIssue
                {
                    Severity = GetUnmanagedSeverityWhenNotManagedYet(knobs),
                    Type = DriftType.UnexpectedUnmanagedRow,
                    Table = "SUserInterface.GridViewActions",
                    RecordGuid = db.Guid,
                    Message = "DB action exists but actions[] is not managed by manifest (null/absent).",
                    Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "actions")
                });
            }

            return issues;
        }

        var manifestByGuid = manifestActions.ToDictionary(x => x.Guid, x => x);
        var dbByGuid = dbActions.ToDictionary(x => x.Guid, x => x);

        foreach (var m in manifestActions.OrderBy(x => x.Guid))
        {
            if (!dbByGuid.ContainsKey(m.Guid))
            {
                issues.Add(new ValidationIssue
                {
                    Severity = DriftSeverity.Fail,
                    Type = DriftType.Missing,
                    Table = "SUserInterface.GridViewActions",
                    RecordGuid = m.Guid,
                    Message = "Manifest action GUID does not exist in DB.",
                    Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "actions")
                });
            }
        }

        var unmanagedSeverity = GetUnmanagedSeverity(environment, knobs);

        foreach (var db in dbActions.OrderBy(x => x.Guid))
        {
            if (!manifestByGuid.ContainsKey(db.Guid))
            {
                issues.Add(new ValidationIssue
                {
                    Severity = unmanagedSeverity,
                    Type = DriftType.UnexpectedUnmanagedRow,
                    Table = "SUserInterface.GridViewActions",
                    RecordGuid = db.Guid,
                    Message = "DB action exists but is not represented in manifest actions[].",
                    Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "actions")
                });
            }
        }

        foreach (var m in manifestActions.OrderBy(x => x.Guid))
        {
            if (!dbByGuid.TryGetValue(m.Guid, out var db))
                continue;

            CompareIntIfPresent(issues, "SUserInterface.GridViewActions", m.Guid,
                "RowStatus", m.RowStatus, db.RowStatus, gridGuid, gridCode, viewGuid, viewCode, "actions");

            if (m.LanguageLabel is not null)
            {
                ResolveAndCompareIntRef(
                    issues, "SUserInterface.GridViewActions", m.Guid,
                    "LanguageLabelId",
                    m.LanguageLabel,
                    "SCore.LanguageLabels",
                    languageLabelGuidToId,
                    db.LanguageLabelId,
                    gridGuid, gridCode, viewGuid, viewCode, "actions");
            }

            if (m.EntityQuery is not null)
            {
                ResolveAndCompareIntRef(
                    issues, "SUserInterface.GridViewActions", m.Guid,
                    "EntityQueryId",
                    m.EntityQuery,
                    "SCore.EntityQueries",
                    entityQueryGuidToId,
                    db.EntityQueryId,
                    gridGuid, gridCode, viewGuid, viewCode, "actions");
            }
        }

        return issues;
    }

    public static List<ValidationIssue> CompareWidgets(
        string environment,
        GridInternalsSeverityKnobs knobs,
        Guid gridGuid,
        string gridCode,
        Guid viewGuid,
        string viewCode,
        IReadOnlyList<GridViewWidgetQueryV1>? manifestWidgets,
        IReadOnlyList<GridViewWidgetRow> dbWidgets,
        IReadOnlyDictionary<Guid, int> languageLabelGuidToId,
        IReadOnlyDictionary<Guid, int> entityQueryGuidToId,
        IReadOnlyDictionary<Guid, short> widgetTypeGuidToId)
    {
        var issues = new List<ValidationIssue>();

        if (manifestWidgets is null)
        {
            foreach (var db in dbWidgets.OrderBy(x => x.Guid))
            {
                issues.Add(new ValidationIssue
                {
                    Severity = GetUnmanagedSeverityWhenNotManagedYet(knobs),
                    Type = DriftType.UnexpectedUnmanagedRow,
                    Table = "SUserInterface.GridViewWidgetQueries",
                    RecordGuid = db.Guid,
                    Message = "DB widget exists but widgets[] is not managed by manifest (null/absent).",
                    Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "widgets")
                });
            }

            return issues;
        }

        var manifestByGuid = manifestWidgets.ToDictionary(x => x.Guid, x => x);
        var dbByGuid = dbWidgets.ToDictionary(x => x.Guid, x => x);

        foreach (var m in manifestWidgets.OrderBy(x => x.Guid))
        {
            if (!dbByGuid.ContainsKey(m.Guid))
            {
                issues.Add(new ValidationIssue
                {
                    Severity = DriftSeverity.Fail,
                    Type = DriftType.Missing,
                    Table = "SUserInterface.GridViewWidgetQueries",
                    RecordGuid = m.Guid,
                    Message = "Manifest widget GUID does not exist in DB.",
                    Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "widgets")
                });
            }
        }

        var unmanagedSeverity = GetUnmanagedSeverity(environment, knobs);

        foreach (var db in dbWidgets.OrderBy(x => x.Guid))
        {
            if (!manifestByGuid.ContainsKey(db.Guid))
            {
                issues.Add(new ValidationIssue
                {
                    Severity = unmanagedSeverity,
                    Type = DriftType.UnexpectedUnmanagedRow,
                    Table = "SUserInterface.GridViewWidgetQueries",
                    RecordGuid = db.Guid,
                    Message = "DB widget exists but is not represented in manifest widgets[].",
                    Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "widgets")
                });
            }
        }

        foreach (var m in manifestWidgets.OrderBy(x => x.Guid))
        {
            if (!dbByGuid.TryGetValue(m.Guid, out var db))
                continue;

            CompareIntIfPresent(issues, "SUserInterface.GridViewWidgetQueries", m.Guid,
                "RowStatus", m.RowStatus, db.RowStatus, gridGuid, gridCode, viewGuid, viewCode, "widgets");

            if (m.LanguageLabel is not null)
            {
                ResolveAndCompareIntRef(
                    issues, "SUserInterface.GridViewWidgetQueries", m.Guid,
                    "LanguageLabelID",
                    m.LanguageLabel,
                    "SCore.LanguageLabels",
                    languageLabelGuidToId,
                    db.LanguageLabelId,
                    gridGuid, gridCode, viewGuid, viewCode, "widgets");
            }

            if (m.EntityQuery is not null)
            {
                ResolveAndCompareIntRef(
                    issues, "SUserInterface.GridViewWidgetQueries", m.Guid,
                    "EntityQueryId",
                    m.EntityQuery,
                    "SCore.EntityQueries",
                    entityQueryGuidToId,
                    db.EntityQueryId,
                    gridGuid, gridCode, viewGuid, viewCode, "widgets");
            }

            if (m.WidgetType is not null)
            {
                if (!TryResolveGuidRef(m.WidgetType, "SUserInterface.WidgetTypes", out var wtGuid))
                {
                    issues.Add(new ValidationIssue
                    {
                        Severity = DriftSeverity.Fail,
                        Type = DriftType.UnresolvableReference,
                        Table = "SUserInterface.GridViewWidgetQueries",
                        RecordGuid = m.Guid,
                        Message = "Widget.widgetType must be a guid reference to SUserInterface.WidgetTypes.",
                        Details = MergeDetails(BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "widgets"),
                            ("ref", m.WidgetType.RefTable), ("key", m.WidgetType.Key), ("value", m.WidgetType.Value))
                    });
                }
                else if (!widgetTypeGuidToId.TryGetValue(wtGuid, out var expectedId))
                {
                    issues.Add(new ValidationIssue
                    {
                        Severity = DriftSeverity.Fail,
                        Type = DriftType.UnresolvableReference,
                        Table = "SUserInterface.WidgetTypes",
                        RecordGuid = wtGuid,
                        Message = "Referenced WidgetType not found in DB.",
                        Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "widgets")
                    });
                }
                else
                {
                    if (expectedId != db.WidgetTypeId)
                    {
                        issues.Add(new ValidationIssue
                        {
                            Severity = DriftSeverity.Fail,
                            Type = DriftType.Different,
                            Table = "SUserInterface.GridViewWidgetQueries",
                            RecordGuid = m.Guid,
                            Message = "Value differs for WidgetTypeId.",
                            Details = MergeDetails(BaseDetails(gridGuid, gridCode, viewGuid, viewCode, "widgets"),
                                ("column", "WidgetTypeId"),
                                ("expected", expectedId.ToString()),
                                ("actual", db.WidgetTypeId.ToString()))
                        });
                    }
                }
            }
        }

        return issues;
    }

    // ------------------------
    // Deterministic helpers
    // ------------------------

    private static Dictionary<string, string> BaseDetails(Guid gridGuid, string gridCode, Guid viewGuid, string viewCode, string internalsKind)
        => new()
        {
            ["gridGuid"] = gridGuid.ToString(),
            ["gridCode"] = gridCode,
            ["viewGuid"] = viewGuid.ToString(),
            ["viewCode"] = viewCode,
            ["internals"] = internalsKind
        };

    private static Dictionary<string, string> MergeDetails(Dictionary<string, string> baseDetails, params (string k, string v)[] extra)
    {
        var d = new Dictionary<string, string>(baseDetails, StringComparer.Ordinal);
        foreach (var (k, v) in extra)
            d[k] = v;
        return d;
    }

    private static bool TryResolveGuidRef(RefV1 r, string expectedRefTable, out Guid guid)
    {
        guid = Guid.Empty;

        if (!string.Equals(r.RefTable, expectedRefTable, StringComparison.OrdinalIgnoreCase))
            return false;

        if (!string.Equals(r.Key, "guid", StringComparison.OrdinalIgnoreCase))
            return false;

        return Guid.TryParse(r.Value, out guid);
    }

    private static void ResolveAndCompareIntRef(
        List<ValidationIssue> issues,
        string owningTable,
        Guid recordGuid,
        string owningColumn,
        RefV1 reference,
        string expectedRefTable,
        IReadOnlyDictionary<Guid, int> guidToId,
        int actualDbId,
        Guid gridGuid,
        string gridCode,
        Guid viewGuid,
        string viewCode,
        string internalsKind)
    {
        if (!TryResolveGuidRef(reference, expectedRefTable, out var refGuid))
        {
            issues.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.UnresolvableReference,
                Table = owningTable,
                RecordGuid = recordGuid,
                Message = $"Reference for '{owningColumn}' must be a guid reference to {expectedRefTable}.",
                Details = MergeDetails(BaseDetails(gridGuid, gridCode, viewGuid, viewCode, internalsKind),
                    ("column", owningColumn),
                    ("ref", reference.RefTable),
                    ("key", reference.Key),
                    ("value", reference.Value))
            });
            return;
        }

        if (!guidToId.TryGetValue(refGuid, out var expectedId))
        {
            issues.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.UnresolvableReference,
                Table = expectedRefTable,
                RecordGuid = refGuid,
                Message = "Referenced prerequisite row not found in DB.",
                Details = BaseDetails(gridGuid, gridCode, viewGuid, viewCode, internalsKind)
            });
            return;
        }

        if (expectedId != actualDbId)
        {
            issues.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.Different,
                Table = owningTable,
                RecordGuid = recordGuid,
                Message = $"Value differs for {owningColumn}.",
                Details = MergeDetails(BaseDetails(gridGuid, gridCode, viewGuid, viewCode, internalsKind),
                    ("column", owningColumn),
                    ("expected", expectedId.ToString()),
                    ("actual", actualDbId.ToString()))
            });
        }
    }

    private static void CompareStringIfPresent(
        List<ValidationIssue> issues,
        string table,
        Guid recordGuid,
        string column,
        string? expected,
        string actual,
        Guid gridGuid,
        string gridCode,
        Guid viewGuid,
        string viewCode,
        string internalsKind)
    {
        if (expected is null) return;

        if (!string.Equals(expected, actual, StringComparison.Ordinal))
        {
            issues.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.Different,
                Table = table,
                RecordGuid = recordGuid,
                Message = $"Value differs for {column}.",
                Details = MergeDetails(BaseDetails(gridGuid, gridCode, viewGuid, viewCode, internalsKind),
                    ("column", column),
                    ("expected", expected),
                    ("actual", actual))
            });
        }
    }

    private static void CompareBoolIfPresent(
        List<ValidationIssue> issues,
        string table,
        Guid recordGuid,
        string column,
        bool? expected,
        bool actual,
        Guid gridGuid,
        string gridCode,
        Guid viewGuid,
        string viewCode,
        string internalsKind)
    {
        if (!expected.HasValue) return;

        if (expected.Value != actual)
        {
            issues.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.Different,
                Table = table,
                RecordGuid = recordGuid,
                Message = $"Value differs for {column}.",
                Details = MergeDetails(BaseDetails(gridGuid, gridCode, viewGuid, viewCode, internalsKind),
                    ("column", column),
                    ("expected", expected.Value ? "true" : "false"),
                    ("actual", actual ? "true" : "false"))
            });
        }
    }

    private static void CompareIntIfPresent(
        List<ValidationIssue> issues,
        string table,
        Guid recordGuid,
        string column,
        int? expected,
        int actual,
        Guid gridGuid,
        string gridCode,
        Guid viewGuid,
        string viewCode,
        string internalsKind)
    {
        if (!expected.HasValue) return;

        if (expected.Value != actual)
        {
            issues.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.Different,
                Table = table,
                RecordGuid = recordGuid,
                Message = $"Value differs for {column}.",
                Details = MergeDetails(BaseDetails(gridGuid, gridCode, viewGuid, viewCode, internalsKind),
                    ("column", column),
                    ("expected", expected.Value.ToString()),
                    ("actual", actual.ToString()))
            });
        }
    }

    private static void CompareIntExact(
        List<ValidationIssue> issues,
        string table,
        Guid recordGuid,
        string column,
        int expected,
        int actual,
        Guid gridGuid,
        string gridCode,
        Guid viewGuid,
        string viewCode,
        string internalsKind)
    {
        if (expected != actual)
        {
            issues.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.Different,
                Table = table,
                RecordGuid = recordGuid,
                Message = $"Value differs for {column}.",
                Details = MergeDetails(BaseDetails(gridGuid, gridCode, viewGuid, viewCode, internalsKind),
                    ("column", column),
                    ("expected", expected.ToString()),
                    ("actual", actual.ToString()))
            });
        }
    }
}
