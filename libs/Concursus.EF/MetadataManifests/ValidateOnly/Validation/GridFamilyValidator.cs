using Concursus.EF.MetadataManifests.ValidateOnly.ManifestModels;
using Concursus.EF.MetadataManifests.ValidateOnly.Policies;
using Concursus.EF.MetadataManifests.ValidateOnly.Reporting;
using Concursus.EF.MetadataManifests.ValidateOnly.Sql;
using static Concursus.EF.MetadataManifests.ValidateOnly.Validation.GridInternalsComparer;

namespace Concursus.EF.MetadataManifests.ValidateOnly.Validation;

public sealed class GridFamilyValidator
{
    private readonly SqlMetadataReader _sql;

    public GridFamilyValidator(SqlMetadataReader sql)
    {
        _sql = sql;
    }

    public async Task<ValidationReport> ValidateAsync(
        string environment,
        string manifestPath,
        GridFamilyManifestV1 manifest,
        string allowlistPath,
        GridAllowlist allowlist,
        bool includeInternals,
        GridInternalsSeverityKnobs? severityKnobs,
        CancellationToken ct)
    {
        var report = new ValidationReport
        {
            Environment = environment,
            Family = "grids",
            ManifestPath = manifestPath,
            AllowlistPath = allowlistPath,
        };

        if (!string.Equals(manifest.Family, "grids", StringComparison.OrdinalIgnoreCase))
        {
            report.Items.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.InvalidManifest,
                Table = "Manifest",
                Message = $"Manifest family was '{manifest.Family}', expected 'grids'."
            });
            report.FinalizeReport();
            return report;
        }

        var allowed = new HashSet<Guid>(allowlist.GridDefinitionGuids);
        var managedGrids = manifest.Grids.Where(g => allowed.Contains(g.Guid)).ToList();

        if (allowed.Count > 0 && managedGrids.Count == 0)
        {
            report.Items.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.InvalidManifest,
                Table = "SUserInterface.GridDefinitions",
                Message = "Allowlist contains GUIDs, but none were found in the manifest. This would validate nothing."
            });
            report.FinalizeReport();
            return report;
        }

        // Stage 2 – internals sections are gated behind --include-internals true.
        if (includeInternals)
        {
            report.InternalsCounts = new InternalsCountsSection { Enabled = true };
            report.InternalsValidation = new InternalsValidationSection { Enabled = true };
        }

        // Task 2.5: severity knobs are optional; use locked defaults if not supplied.
        var knobs = severityKnobs ?? GridInternalsSeverityKnobs.Default;

        // --------------------------------------------------------------------
        // Prerequisites collection
        // Stage 2 – Task 2.2: optional arrays (null/absent => not managed)
        // Stage 2 – Task 2.3: include internals prereqs only when includeInternals
        // --------------------------------------------------------------------

        var languageLabelGuids = new HashSet<Guid>();
        var entityQueryGuids = new HashSet<Guid>();
        var widgetTypeGuids = new HashSet<Guid>();

        foreach (var g in managedGrids)
        {
            ExtractGuidRef(languageLabelGuids, g.LanguageLabel, expectedRef: "SCore.LanguageLabels");

            foreach (var v in g.Views)
            {
                ExtractGuidRef(languageLabelGuids, v.LanguageLabel, expectedRef: "SCore.LanguageLabels");

                if (!includeInternals)
                    continue;

                // Only collect internals prereqs if the arrays are present (managed).
                if (v.Columns is not null)
                {
                    foreach (var c in v.Columns)
                        ExtractGuidRef(languageLabelGuids, c.LanguageLabel, expectedRef: "SCore.LanguageLabels");
                }

                if (v.Actions is not null)
                {
                    foreach (var a in v.Actions)
                    {
                        ExtractGuidRef(languageLabelGuids, a.LanguageLabel, expectedRef: "SCore.LanguageLabels");
                        ExtractGuidRef(entityQueryGuids, a.EntityQuery, expectedRef: "SCore.EntityQueries");
                    }
                }

                if (v.Widgets is not null)
                {
                    foreach (var w in v.Widgets)
                    {
                        ExtractGuidRef(languageLabelGuids, w.LanguageLabel, expectedRef: "SCore.LanguageLabels");
                        ExtractGuidRef(entityQueryGuids, w.EntityQuery, expectedRef: "SCore.EntityQueries");
                        ExtractGuidRef(widgetTypeGuids, w.WidgetType, expectedRef: "SUserInterface.WidgetTypes");
                    }
                }
            }
        }

        // Resolve prerequisite maps (must pre-exist if referenced).
        var llMap = await _sql.ResolveLanguageLabelIdsByGuidAsync(languageLabelGuids, ct).ConfigureAwait(false);

        Dictionary<Guid, int> eqMap = new();
        Dictionary<Guid, short> wtMap = new();

        if (includeInternals)
        {
            eqMap = await _sql.ResolveEntityQueryIdsByGuidAsync(entityQueryGuids, ct).ConfigureAwait(false);
            wtMap = await _sql.ResolveWidgetTypeIdsByGuidAsync(widgetTypeGuids, ct).ConfigureAwait(false);
        }

        foreach (var requiredGuid in languageLabelGuids)
        {
            if (!llMap.ContainsKey(requiredGuid))
            {
                report.Items.Add(new ValidationIssue
                {
                    Severity = DriftSeverity.Fail,
                    Type = DriftType.UnresolvableReference,
                    Table = "SCore.LanguageLabels",
                    RecordGuid = requiredGuid,
                    Message = "Prerequisite reference could not be resolved: LanguageLabel Guid not found in DB."
                });
            }
        }

        if (includeInternals)
        {
            foreach (var requiredGuid in entityQueryGuids)
            {
                if (!eqMap.ContainsKey(requiredGuid))
                {
                    report.Items.Add(new ValidationIssue
                    {
                        Severity = DriftSeverity.Fail,
                        Type = DriftType.UnresolvableReference,
                        Table = "SCore.EntityQueries",
                        RecordGuid = requiredGuid,
                        Message = "Prerequisite reference could not be resolved: EntityQuery Guid not found in DB."
                    });
                }
            }

            foreach (var requiredGuid in widgetTypeGuids)
            {
                if (!wtMap.ContainsKey(requiredGuid))
                {
                    report.Items.Add(new ValidationIssue
                    {
                        Severity = DriftSeverity.Fail,
                        Type = DriftType.UnresolvableReference,
                        Table = "SUserInterface.WidgetTypes",
                        RecordGuid = requiredGuid,
                        Message = "Prerequisite reference could not be resolved: WidgetType Guid not found in DB."
                    });
                }
            }
        }

        // --------------------------------------------------------------------
        // Validate allow-listed grids
        // --------------------------------------------------------------------

        foreach (var grid in managedGrids)
        {
            ct.ThrowIfCancellationRequested();

            var dbGrid = await _sql.GetGridDefinitionByGuidAsync(grid.Guid, ct).ConfigureAwait(false);
            if (dbGrid is null)
            {
                report.Items.Add(new ValidationIssue
                {
                    Severity = DriftSeverity.Fail,
                    Type = DriftType.Missing,
                    Table = "SUserInterface.GridDefinitions",
                    RecordGuid = grid.Guid,
                    Message = "GridDefinition Guid from manifest does not exist in DB."
                });
                continue;
            }

            // Stage 1 comparisons (unchanged)
            CompareStringIfPresent(report, "SUserInterface.GridDefinitions", grid.Guid, "Code", grid.Code, dbGrid.Code);
            CompareIntIfPresent(report, "SUserInterface.GridDefinitions", grid.Guid, "RowStatus", grid.RowStatus, dbGrid.RowStatus);
            CompareStringIfPresent(report, "SUserInterface.GridDefinitions", grid.Guid, "PageUri", grid.PageUri, dbGrid.PageUri);
            CompareStringIfPresent(report, "SUserInterface.GridDefinitions", grid.Guid, "TabName", grid.TabName, dbGrid.TabName);
            CompareBoolIfPresent(report, "SUserInterface.GridDefinitions", grid.Guid, "ShowAsTiles", grid.ShowAsTiles, dbGrid.ShowAsTiles);

            if (grid.LanguageLabel is not null)
            {
                var expected = ResolveIntRefOrFail(report, "SUserInterface.GridDefinitions", grid.Guid, "LanguageLabelId", grid.LanguageLabel, llMap);
                if (expected.HasValue)
                    CompareNullableIntExact(report, "SUserInterface.GridDefinitions", grid.Guid, "LanguageLabelId", expected.Value, dbGrid.LanguageLabelId);
            }

            var dbViews = await _sql.GetGridViewsByGridDefinitionIdAsync(dbGrid.Id, ct).ConfigureAwait(false);
            var dbViewByGuid = dbViews.ToDictionary(v => v.Guid, v => v);

            // Task 2.1 counts (unchanged)
            Dictionary<Guid, int>? colCounts = null;
            Dictionary<Guid, int>? actCounts = null;
            Dictionary<Guid, int>? widCounts = null;

            if (includeInternals)
            {
                colCounts = await _sql.GetGridViewColumnCountsByGridDefinitionIdAsync(dbGrid.Id, ct).ConfigureAwait(false);
                actCounts = await _sql.GetGridViewActionCountsByGridDefinitionIdAsync(dbGrid.Id, ct).ConfigureAwait(false);
                widCounts = await _sql.GetGridViewWidgetCountsByGridDefinitionIdAsync(dbGrid.Id, ct).ConfigureAwait(false);
            }

            foreach (var view in grid.Views)
            {
                if (!dbViewByGuid.TryGetValue(view.Guid, out var dbView))
                {
                    report.Items.Add(new ValidationIssue
                    {
                        Severity = DriftSeverity.Fail,
                        Type = DriftType.Missing,
                        Table = "SUserInterface.GridViewDefinitions",
                        RecordGuid = view.Guid,
                        Message = $"GridViewDefinition Guid from manifest does not exist in DB for GridDefinition '{dbGrid.Code}'."
                    });
                    continue;
                }

                // Stage 1 comparisons (unchanged)
                CompareStringIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "Code", view.Code, dbView.Code);
                CompareIntIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "RowStatus", view.RowStatus, dbView.RowStatus);

                CompareStringIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "DetailPageUri", view.DetailPageUri, dbView.DetailPageUri);
                CompareStringIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "SqlQuery", view.SqlQuery, dbView.SqlQuery);
                CompareStringIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "DefaultSortColumnName", view.DefaultSortColumnName, dbView.DefaultSortColumnName);
                CompareBoolIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "IsDefaultSortDescending", view.IsDefaultSortDescending, dbView.IsDefaultSortDescending);
                CompareStringIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "SecurableCode", view.SecurableCode, dbView.SecurableCode);
                CompareIntIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "DisplayOrder", view.DisplayOrder, dbView.DisplayOrder);
                CompareStringIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "DisplayGroupName", view.DisplayGroupName, dbView.DisplayGroupName);
                CompareBoolIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "ShowOnMobile", view.ShowOnMobile, dbView.ShowOnMobile);
                CompareBoolIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "ShowOnDashboard", view.ShowOnDashboard, dbView.ShowOnDashboard);

                CompareBoolIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "AllowNew", view.AllowNew, dbView.AllowNew);
                CompareBoolIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "AllowExcelExport", view.AllowExcelExport, dbView.AllowExcelExport);
                CompareBoolIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "AllowPdfExport", view.AllowPdfExport, dbView.AllowPdfExport);
                CompareBoolIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "AllowCsvExport", view.AllowCsvExport, dbView.AllowCsvExport);
                CompareBoolIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "AllowBulkChange", view.AllowBulkChange, dbView.AllowBulkChange);
                CompareBoolIfPresent(report, "SUserInterface.GridViewDefinitions", view.Guid, "IsDetailWindowed", view.IsDetailWindowed, dbView.IsDetailWindowed);

                if (view.LanguageLabel is not null)
                {
                    var expected = ResolveIntRefOrFail(report, "SUserInterface.GridViewDefinitions", view.Guid, "LanguageLabelId", view.LanguageLabel, llMap);
                    if (expected.HasValue)
                        CompareNullableIntExact(report, "SUserInterface.GridViewDefinitions", view.Guid, "LanguageLabelId", expected.Value, dbView.LanguageLabelId);
                }

                // Task 2.1 counts section (unchanged)
                if (includeInternals && report.InternalsCounts is not null)
                {
                    var col = (colCounts is not null && colCounts.TryGetValue(view.Guid, out var c)) ? c : 0;
                    var act = (actCounts is not null && actCounts.TryGetValue(view.Guid, out var a)) ? a : 0;
                    var wid = (widCounts is not null && widCounts.TryGetValue(view.Guid, out var w)) ? w : 0;

                    report.InternalsCounts.Views.Add(new ViewInternalsCount
                    {
                        GridGuid = grid.Guid,
                        GridCode = grid.Code ?? dbGrid.Code,
                        ViewGuid = view.Guid,
                        ViewCode = view.Code ?? dbView.Code,
                        ColumnCount = col,
                        ActionCount = act,
                        WidgetCount = wid
                    });
                }

                // ----------------------------------------------------------------
                // Stage 2 – internals validation (Task 2.3)
                // Only runs when includeInternals true
                // ----------------------------------------------------------------
                if (includeInternals && report.InternalsValidation is not null)
                {
                    var dbCols = await _sql.GetGridViewColumnsByViewIdAsync(dbView.Id, ct).ConfigureAwait(false);
                    var dbActs = await _sql.GetGridViewActionsByViewIdAsync(dbView.Id, ct).ConfigureAwait(false);
                    var dbWids = await _sql.GetGridViewWidgetsByViewIdAsync(dbView.Id, ct).ConfigureAwait(false);

                    report.InternalsValidation.Views.Add(new ViewInternalsValidation
                    {
                        GridGuid = grid.Guid,
                        GridCode = grid.Code ?? dbGrid.Code,
                        ViewGuid = view.Guid,
                        ViewCode = view.Code ?? dbView.Code,

                        ColumnsManaged = view.Columns is not null,
                        ActionsManaged = view.Actions is not null,
                        WidgetsManaged = view.Widgets is not null,

                        DbColumnCount = dbCols.Count,
                        DbActionCount = dbActs.Count,
                        DbWidgetCount = dbWids.Count,

                        ManifestColumnCount = view.Columns?.Count,
                        ManifestActionCount = view.Actions?.Count,
                        ManifestWidgetCount = view.Widgets?.Count
                    });

                    var gridCode = grid.Code ?? dbGrid.Code;
                    var viewCode = view.Code ?? dbView.Code;

                    report.Items.AddRange(GridInternalsComparer.CompareColumns(
                        environment, knobs, grid.Guid, gridCode, view.Guid, viewCode,
                        view.Columns, dbCols, llMap));

                    report.Items.AddRange(GridInternalsComparer.CompareActions(
                        environment, knobs, grid.Guid, gridCode, view.Guid, viewCode,
                        view.Actions, dbActs, llMap, eqMap));

                    report.Items.AddRange(GridInternalsComparer.CompareWidgets(
                        environment, knobs, grid.Guid, gridCode, view.Guid, viewCode,
                        view.Widgets, dbWids, llMap, eqMap, wtMap));
                }
            }
        }

        report.FinalizeReport();
        return report;
    }

    // -----------------------------
    // Shared helpers (Stage 1 + 2)
    // -----------------------------

    private static void ExtractGuidRef(HashSet<Guid> into, RefV1? r, string expectedRef)
    {
        if (r is null) return;
        if (!string.Equals(r.RefTable, expectedRef, StringComparison.OrdinalIgnoreCase)) return;
        if (!string.Equals(r.Key, "guid", StringComparison.OrdinalIgnoreCase)) return;
        if (Guid.TryParse(r.Value, out var g))
            into.Add(g);
    }

    private static int? ResolveIntRefOrFail(
        ValidationReport report,
        string owningTable,
        Guid owningGuid,
        string owningColumn,
        RefV1 reference,
        Dictionary<Guid, int> guidToIdMap)
    {
        if (!string.Equals(reference.Key, "guid", StringComparison.OrdinalIgnoreCase) ||
            !Guid.TryParse(reference.Value, out var g))
        {
            report.Items.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.UnresolvableReference,
                Table = owningTable,
                RecordGuid = owningGuid,
                Message = $"Reference for '{owningColumn}' must be a Guid reference at Stage 1/2.",
                Details = new Dictionary<string, string>
                {
                    ["ref"] = reference.RefTable,
                    ["key"] = reference.Key,
                    ["value"] = reference.Value
                }
            });
            return null;
        }

        if (!guidToIdMap.TryGetValue(g, out var id))
        {
            report.Items.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.UnresolvableReference,
                Table = reference.RefTable,
                RecordGuid = g,
                Message = $"Referenced prerequisite row not found for '{owningTable}.{owningColumn}'."
            });
            return null;
        }

        return id;
    }

    private static void CompareStringIfPresent(
        ValidationReport report,
        string table,
        Guid recordGuid,
        string column,
        string? expected,
        string? actual)
    {
        if (expected is null) return;
        if (!string.Equals(expected, actual, StringComparison.Ordinal))
        {
            report.Items.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.Different,
                Table = table,
                RecordGuid = recordGuid,
                Message = $"Value differs for {column}.",
                Details = new Dictionary<string, string>
                {
                    ["column"] = column,
                    ["expected"] = expected,
                    ["actual"] = actual ?? "<null>"
                }
            });
        }
    }

    private static void CompareBoolIfPresent(
        ValidationReport report,
        string table,
        Guid recordGuid,
        string column,
        bool? expected,
        bool actual)
    {
        if (!expected.HasValue) return;
        if (expected.Value != actual)
        {
            report.Items.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.Different,
                Table = table,
                RecordGuid = recordGuid,
                Message = $"Value differs for {column}.",
                Details = new Dictionary<string, string>
                {
                    ["column"] = column,
                    ["expected"] = expected.Value ? "true" : "false",
                    ["actual"] = actual ? "true" : "false"
                }
            });
        }
    }

    private static void CompareIntIfPresent(
        ValidationReport report,
        string table,
        Guid recordGuid,
        string column,
        int? expected,
        int actualFromDbByteOrInt)
    {
        if (!expected.HasValue) return;
        if (expected.Value != actualFromDbByteOrInt)
        {
            report.Items.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.Different,
                Table = table,
                RecordGuid = recordGuid,
                Message = $"Value differs for {column}.",
                Details = new Dictionary<string, string>
                {
                    ["column"] = column,
                    ["expected"] = expected.Value.ToString(),
                    ["actual"] = actualFromDbByteOrInt.ToString()
                }
            });
        }
    }

    private static void CompareNullableIntExact(
        ValidationReport report,
        string table,
        Guid recordGuid,
        string column,
        int expected,
        int? actual)
    {
        if (!actual.HasValue || expected != actual.Value)
        {
            report.Items.Add(new ValidationIssue
            {
                Severity = DriftSeverity.Fail,
                Type = DriftType.Different,
                Table = table,
                RecordGuid = recordGuid,
                Message = $"Value differs for {column}.",
                Details = new Dictionary<string, string>
                {
                    ["column"] = column,
                    ["expected"] = expected.ToString(),
                    ["actual"] = actual?.ToString() ?? "<null>"
                }
            });
        }
    }
}
