using System.Text.Json;
using Concursus.EF.SchemaMigration;
using Microsoft.Extensions.Configuration;

namespace Concursus.EF.MigrationCli;

/// <summary>
/// Headless Schema Migration preparation for the deploy script. <c>schema-prepare</c> leaves the target
/// with exactly one accepted, unapplied, recently compared run that the existing PowerShell runner
/// (tools/SchemaDeployment/Invoke-CymBuildSchemaDeployment.ps1) can -SyncSource and -Apply. It drives
/// <see cref="SchemaMigrationEngine"/>, the same code the workbench RPCs use, so the run is identical to
/// one created, compared, selected, validated and accepted in the UI.
/// </summary>
/// <remarks>
/// Exit codes: 0 success or nothing to do; 2 handled failure (the JSON report still carries the
/// message); 4 usage error.
/// </remarks>
public static class SchemaMigrationCli
{
    /// <summary>An accepted run compared within this window is reused as is (the runner's own limit is 30 minutes).</summary>
    public static readonly TimeSpan AcceptedRunReuseWindow = TimeSpan.FromMinutes(25);

    private const string Usage =
        "Usage: schema-prepare --target-server <server> --target-database <db> --source-server <server> --source-database <db> " +
        "[--source-environment DEV] [--target-environment QA] [--notes <text>] [--out <json path>] [--connection-template <connection string>]";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    public static async Task<int> RunAsync(string[] args, CancellationToken ct)
    {
        if (args.Length == 0)
        {
            Console.Error.WriteLine("No command. Expected: schema-prepare");
            Console.Error.WriteLine(Usage);
            return 4;
        }

        var cmd = args[0].Trim().ToLowerInvariant();
        if (cmd != "schema-prepare")
        {
            Console.Error.WriteLine($"Unknown command '{args[0]}'. Expected: schema-prepare");
            return 4;
        }

        var parsed = ParseArgs(args.Skip(1).ToArray());
        SchemaPrepareOptions options;
        try
        {
            options = new SchemaPrepareOptions(
                TargetServer: GetRequired(parsed, "--target-server"),
                TargetDatabase: GetRequired(parsed, "--target-database"),
                SourceServer: GetRequired(parsed, "--source-server"),
                SourceDatabase: GetRequired(parsed, "--source-database"),
                SourceEnvironment: GetOptional(parsed, "--source-environment", "DEV"),
                TargetEnvironment: GetOptional(parsed, "--target-environment", "QA"),
                Notes: GetOptional(parsed, "--notes", "Prepared headlessly by the CymBuild deploy script (schema-prepare)."),
                OutPath: GetOptional(parsed, "--out", "schema-prepare-result.json"),
                ConnectionTemplate: parsed.TryGetValue("--connection-template", out var template) ? template : null);
        }
        catch (ArgumentException ex)
        {
            Console.Error.WriteLine(ex.Message);
            Console.Error.WriteLine(Usage);
            return 4;
        }

        IConfiguration configuration = string.IsNullOrWhiteSpace(options.ConnectionTemplate)
            ? ConnectionStringConfiguration.ForIntegratedSecurity(options.TargetServer, options.TargetDatabase)
            : new ConnectionStringConfiguration(options.ConnectionTemplate);

        var engine = new SchemaMigrationEngine(configuration);
        var report = new SchemaPrepareReport();

        int exitCode;
        try
        {
            exitCode = await PrepareAsync(engine, options, report, DateTime.UtcNow, ct).ConfigureAwait(false);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            // SchemaMigrationException (refusal), MigrationBootstrapException, SqlException and the
            // compare lifecycle's InvalidOperationException all land here so the deploy script always
            // gets a JSON report it can show.
            report.Message = ex.InnerException is null
                ? $"{ex.GetType().Name}: {ex.Message}"
                : $"{ex.GetType().Name}: {ex.Message} Inner: {ex.InnerException.Message}";
            exitCode = 2;
        }

        await WriteReportAsync(options.OutPath, report, ct).ConfigureAwait(false);

        Console.WriteLine($"schema-prepare: mode={report.Mode}, run={report.RunGuid}, selected={report.Selected.Count}, skipped={report.Skipped.Count}, fail={report.FailCount}, warn={report.WarnCount}");
        Console.WriteLine(report.Message);
        Console.WriteLine($"Report: {options.OutPath}");
        return exitCode;
    }

    private static async Task<int> PrepareAsync(
        SchemaMigrationEngine engine,
        SchemaPrepareOptions options,
        SchemaPrepareReport report,
        DateTime utcNow,
        CancellationToken ct)
    {
        var existing = await engine.FindAcceptedUnappliedRunAsync(
            options.TargetServer,
            options.TargetDatabase,
            options.SourceDatabase,
            ct).ConfigureAwait(false);

        if (existing is not null && IsWithinReuseWindow(existing.ComparedOnUtc, utcNow))
        {
            report.Mode = "accepted";
            report.RunGuid = existing.RunGuid.ToString();
            await FillFromRunAsync(engine, options, existing.RunGuid, report, ct).ConfigureAwait(false);
            report.Message = $"Reusing accepted run {existing.RunGuid}, compared {report.ComparedOnUtc} UTC (within {AcceptedRunReuseWindow.TotalMinutes:N0} minutes).";
            return 0;
        }

        if (existing is not null)
        {
            // Re-compare refreshes the plan; selections persist by object key, so the same objects stay
            // selected. The workbench's -SyncSource staleness gate is not enforced here because the deploy
            // script runs -SyncSource immediately after this acceptance, before -WhatIf/-Apply.
            report.Mode = "refreshed";
            report.RunGuid = existing.RunGuid.ToString();
            await engine.CompareAsync(options.TargetServer, options.TargetDatabase, existing.RunGuid, enforceSourceSyncGate: false, ct).ConfigureAwait(false);

            // CYB-584, 2026-10-16 UAT: run d9e94913 was accepted but never applied; by the next deploy its
            // two selected procedures already matched, so the refresh left nothing selected and validation
            // failed NO_SELECTED_ROWS, blocking the metadata step. A refreshed run with no selection left
            // is stale - prepare a new run instead (which finds new differences or nothing to do).
            await FillFromRunAsync(engine, options, existing.RunGuid, report, ct).ConfigureAwait(false);
            if (report.Selected.Count > 0)
            {
                return await ValidateAndAcceptAsync(
                    engine,
                    options,
                    existing.RunGuid,
                    report,
                    $"Refreshed accepted run {existing.RunGuid} (re-compared, revalidated and re-accepted).",
                    ct).ConfigureAwait(false);
            }

            report.Selected.Clear();
        }

        report.Mode = "created";
        var run = await engine.CreateRunAsync(
            new SchemaRunCreateOptions(
                options.SourceEnvironment,
                options.SourceServer,
                options.SourceDatabase,
                options.TargetEnvironment,
                options.TargetServer,
                options.TargetDatabase,
                JiraReference: string.Empty,
                ReleaseReference: string.Empty,
                options.Notes),
            ct).ConfigureAwait(false);
        var runGuid = Guid.Parse(run.RunGuid);
        report.RunGuid = run.RunGuid;

        await engine.CompareAsync(options.TargetServer, options.TargetDatabase, runGuid, enforceSourceSyncGate: false, ct).ConfigureAwait(false);

        var candidates = new List<SchemaComparisonRowRecord>();
        foreach (var differenceType in new[] { "Different", "MissingInTarget", "MissingInSource" })
        {
            var page = await engine.ListComparisonRowsAsync(
                options.TargetServer,
                options.TargetDatabase,
                runGuid,
                differenceType,
                includeDefinitions: true,
                ct).ConfigureAwait(false);
            if (page.MayBeTruncated)
            {
                report.Message = $"Run {runGuid}: more than {SchemaMigrationEngine.SchemaComparisonRowReadLimit:N0} {differenceType} rows; the workbench selection path is capped at that many rows. Prepare this run in the Schema Migration workbench instead.";
                return 2;
            }

            candidates.AddRange(page.Rows);
        }

        // SaveSelection reads the run's rows through the same capped query (non-Equal rows first), so
        // every candidate is only guaranteed to be selectable while the non-Equal total stays below it.
        if (candidates.Count >= SchemaMigrationEngine.SchemaComparisonRowReadLimit)
        {
            report.Message = $"Run {runGuid}: {candidates.Count:N0} differing rows reach the workbench selection cap of {SchemaMigrationEngine.SchemaComparisonRowReadLimit:N0}. Prepare this run in the Schema Migration workbench instead.";
            return 2;
        }

        var plan = SchemaMigrationRules.PlanHeadlessSelection(candidates);
        report.Skipped.AddRange(plan.Skipped.Select(x => new SchemaPrepareSkippedItem(
            x.Row.ObjectType,
            x.Row.SchemaName,
            x.Row.ObjectName,
            x.Row.ParentObjectName,
            x.Row.DifferenceType,
            x.ReasonCode,
            x.Reason)));

        if (plan.Selected.Count == 0)
        {
            report.Mode = "nothing-to-do";
            var refreshedRun = await engine.ReadRunAsync(options.TargetServer, options.TargetDatabase, runGuid, ct).ConfigureAwait(false);
            report.ComparedOnUtc = refreshedRun.ComparedOnUtc;
            report.Message = $"Run {runGuid} found no selectable Different/MissingInTarget schema rows ({plan.Skipped.Count} skipped). Nothing to deploy; the run was left in Compared status.";
            return 0;
        }

        var selectedGuids = plan.Selected.Select(x => Guid.Parse(x.ComparisonGuid)).ToList();
        var counts = await engine.SaveSelectionAsync(
            options.TargetServer,
            options.TargetDatabase,
            runGuid,
            selectedGuids,
            options.Notes,
            ct).ConfigureAwait(false);

        if (counts.SelectedCount != selectedGuids.Count)
        {
            report.Message = $"Run {runGuid}: requested {selectedGuids.Count:N0} rows but the saved selection holds {counts.SelectedCount:N0}. The run was not validated or accepted.";
            return 2;
        }

        return await ValidateAndAcceptAsync(
            engine,
            options,
            runGuid,
            report,
            $"Created run {runGuid}: selected {selectedGuids.Count:N0} row(s), skipped {plan.Skipped.Count:N0}, validated and accepted.",
            ct).ConfigureAwait(false);
    }

    private static async Task<int> ValidateAndAcceptAsync(
        SchemaMigrationEngine engine,
        SchemaPrepareOptions options,
        Guid runGuid,
        SchemaPrepareReport report,
        string successMessage,
        CancellationToken ct)
    {
        var validation = await engine.ValidateAsync(options.TargetServer, options.TargetDatabase, runGuid, ct).ConfigureAwait(false);
        report.FailCount = validation.FailCount;
        report.WarnCount = validation.WarnCount;

        if (validation.FailCount > 0)
        {
            await FillFromRunAsync(engine, options, runGuid, report, ct).ConfigureAwait(false);
            var failures = validation.ValidationIssues
                .Where(x => x.Severity.Equals("Fail", StringComparison.OrdinalIgnoreCase))
                .Take(10)
                .Select(x => $"{x.IssueCode} {x.SchemaName}.{x.ObjectName}: {x.IssueMessage}");
            report.Message = $"Run {runGuid} failed validation with {validation.FailCount} failure(s); it was not accepted. {string.Join(" | ", failures)}";
            return 2;
        }

        var acceptance = await engine.AcceptAsync(options.TargetServer, options.TargetDatabase, runGuid, options.Notes, ct).ConfigureAwait(false);
        await FillFromRunAsync(engine, options, runGuid, report, ct).ConfigureAwait(false);

        if (!acceptance.Success)
        {
            report.Message = $"Run {runGuid} was not accepted: {acceptance.Message}";
            return 2;
        }

        report.Message = successMessage;
        return 0;
    }

    private static async Task FillFromRunAsync(
        SchemaMigrationEngine engine,
        SchemaPrepareOptions options,
        Guid runGuid,
        SchemaPrepareReport report,
        CancellationToken ct)
    {
        var run = await engine.ReadRunAsync(options.TargetServer, options.TargetDatabase, runGuid, ct).ConfigureAwait(false);
        report.ComparedOnUtc = run.ComparedOnUtc;

        report.Selected.Clear();
        foreach (var differenceType in new[] { "Different", "MissingInTarget", "MissingInSource" })
        {
            var page = await engine.ListComparisonRowsAsync(
                options.TargetServer,
                options.TargetDatabase,
                runGuid,
                differenceType,
                includeDefinitions: false,
                ct).ConfigureAwait(false);
            report.Selected.AddRange(page.Rows
                .Where(x => x.IsSelected)
                .Select(x => new SchemaPrepareSelectedItem(x.ObjectType, x.SchemaName, x.ObjectName, x.ParentObjectName, x.DifferenceType)));
        }
    }

    /// <summary>True when <paramref name="comparedOnUtc"/> is within <see cref="AcceptedRunReuseWindow"/> of <paramref name="utcNow"/>.</summary>
    public static bool IsWithinReuseWindow(DateTime? comparedOnUtc, DateTime utcNow) =>
        comparedOnUtc is not null && utcNow - comparedOnUtc.Value <= AcceptedRunReuseWindow;

    private static async Task WriteReportAsync(string outPath, SchemaPrepareReport report, CancellationToken ct)
    {
        var directory = Path.GetDirectoryName(Path.GetFullPath(outPath));
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        await File.WriteAllTextAsync(outPath, JsonSerializer.Serialize(report, JsonOptions), ct).ConfigureAwait(false);
    }

    private static Dictionary<string, string> ParseArgs(string[] args)
    {
        var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < args.Length; i++)
        {
            var k = args[i];
            if (!k.StartsWith("--", StringComparison.Ordinal)) continue;

            var v = (i + 1 < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal))
                ? args[++i]
                : "true";

            d[k] = v;
        }
        return d;
    }

    private static string GetRequired(Dictionary<string, string> args, string key)
    {
        if (!args.TryGetValue(key, out var v) || string.IsNullOrWhiteSpace(v))
            throw new ArgumentException($"Missing required argument: {key}");
        return v;
    }

    private static string GetOptional(Dictionary<string, string> args, string key, string defaultValue) =>
        args.TryGetValue(key, out var v) && !string.IsNullOrWhiteSpace(v) ? v : defaultValue;

    private sealed record SchemaPrepareOptions(
        string TargetServer,
        string TargetDatabase,
        string SourceServer,
        string SourceDatabase,
        string SourceEnvironment,
        string TargetEnvironment,
        string Notes,
        string OutPath,
        string? ConnectionTemplate);

    public sealed class SchemaPrepareReport
    {
        public string Mode { get; set; } = "failed";
        public string RunGuid { get; set; } = string.Empty;
        public string ComparedOnUtc { get; set; } = string.Empty;
        public List<SchemaPrepareSelectedItem> Selected { get; } = [];
        public List<SchemaPrepareSkippedItem> Skipped { get; } = [];
        public int FailCount { get; set; }
        public int WarnCount { get; set; }
        public string Message { get; set; } = string.Empty;
    }

    public sealed record SchemaPrepareSelectedItem(
        string ObjectType,
        string SchemaName,
        string ObjectName,
        string ParentObjectName,
        string DifferenceType);

    public sealed record SchemaPrepareSkippedItem(
        string ObjectType,
        string SchemaName,
        string ObjectName,
        string ParentObjectName,
        string DifferenceType,
        string ReasonCode,
        string Reason);
}
