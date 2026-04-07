using System.Text.Json;
using Concursus.EF.MetadataManifests.ValidateOnly.ManifestModels;
using Concursus.EF.MetadataManifests.ValidateOnly.Policies;
using Concursus.EF.MetadataManifests.ValidateOnly.Reporting;
using Concursus.EF.MetadataManifests.ValidateOnly.Sql;
using Concursus.EF.MetadataManifests.ValidateOnly.Validation;
using static Concursus.EF.MetadataManifests.ValidateOnly.Validation.GridInternalsComparer;

namespace Concursus.EF.MetadataManifests.ValidateOnly.Cli;

/// <summary>
/// Lightweight CLI dispatcher (no external libs) to keep repo churn minimal.
/// Add more commands in later stages.
/// </summary>
public static class MetadataValidateCli
{
    public static async Task<int> RunAsync(string[] args, CancellationToken ct)
    {
        if (args.Length == 0)
        {
            Console.Error.WriteLine("No command. Expected: validate-grids");
            return 4;
        }

        var cmd = args[0].Trim().ToLowerInvariant();
        if (cmd != "validate-grids")
        {
            Console.Error.WriteLine($"Unknown command '{args[0]}'. Expected: validate-grids");
            return 4;
        }

        var parsed = ParseArgs(args.Skip(1).ToArray());

        var connection = GetRequired(parsed, "--connection");
        var manifestPath = GetRequired(parsed, "--manifest");
        var allowlistPath = GetRequired(parsed, "--allowlist");
        var environment = GetRequired(parsed, "--environment");
        var outPath = parsed.TryGetValue("--out", out var o) ? o : "metadata-validation-report.json";

        // Stage 2: gated internals sections
        var includeInternals = ParseBool(parsed, "--include-internals", defaultValue: false);

        // Stage 2 – Task 2.5: severity knobs (optional; defaults locked to governance)
        // These only influence unmanaged drift severity (NOT Missing/Different, which remain FAIL always).
        // If an argument is provided but invalid, we fail fast with exit code 4.
        if (!TryBuildSeverityKnobs(parsed, out var knobs, out var knobsError))
        {
            Console.Error.WriteLine(knobsError);
            return 4;
        }

        var jsonOptions = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            WriteIndented = true
        };

        GridFamilyManifestV1 manifest;
        GridAllowlist allowlist;

        try
        {
            var manifestJson = await File.ReadAllTextAsync(manifestPath, ct).ConfigureAwait(false);
            manifest = JsonSerializer.Deserialize<GridFamilyManifestV1>(manifestJson, jsonOptions)
                       ?? throw new InvalidOperationException("Manifest deserialized to null.");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Failed to load/parse manifest: {ex.Message}");
            return 4;
        }

        try
        {
            var allowJson = await File.ReadAllTextAsync(allowlistPath, ct).ConfigureAwait(false);
            allowlist = JsonSerializer.Deserialize<GridAllowlist>(allowJson, jsonOptions)
                        ?? new GridAllowlist();
        }
        catch
        {
            // Governance: allowlist starts empty. If file missing/invalid, treat as empty but warn.
            allowlist = new GridAllowlist();
        }

        var sql = new SqlMetadataReader(connection);
        var validator = new GridFamilyValidator(sql);

        ValidationReport report = await validator.ValidateAsync(
            environment: environment,
            manifestPath: manifestPath,
            manifest: manifest,
            allowlistPath: allowlistPath,
            allowlist: allowlist,
            includeInternals: includeInternals,
            severityKnobs: knobs,
            ct: ct).ConfigureAwait(false);

        var outJson = JsonSerializer.Serialize(report, jsonOptions);
        await File.WriteAllTextAsync(outPath, outJson, ct).ConfigureAwait(false);

        Console.WriteLine($"Validation completed. Report: {outPath}");
        Console.WriteLine($"FAIL={report.Summary.FailCount}, WARN={report.Summary.WarnCount}, INFO={report.Summary.InfoCount}");

        // Deterministic & controlled console output (counts summary only; data lives in report)
        if (includeInternals)
        {
            var viewCount = report.InternalsCounts?.Views?.Count ?? 0;
            Console.WriteLine($"InternalsCounts enabled. Views included: {viewCount}");
        }

        return report.GetExitCode();
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

    private static bool ParseBool(Dictionary<string, string> args, string key, bool defaultValue)
    {
        if (!args.TryGetValue(key, out var raw) || string.IsNullOrWhiteSpace(raw))
            return defaultValue;

        raw = raw.Trim();

        return raw.Equals("true", StringComparison.OrdinalIgnoreCase)
               || raw.Equals("1", StringComparison.OrdinalIgnoreCase)
               || raw.Equals("yes", StringComparison.OrdinalIgnoreCase)
               || raw.Equals("y", StringComparison.OrdinalIgnoreCase);
    }

    // -----------------------------
    // Stage 2 – Task 2.5 helpers
    // -----------------------------

    private static bool TryBuildSeverityKnobs(
        Dictionary<string, string> parsed,
        out GridInternalsSeverityKnobs knobs,
        out string error)
    {
        // Defaults are locked to governance. These preserve current behaviour if no args provided.
        knobs = GridInternalsSeverityKnobs.Default;
        error = string.Empty;

        // Optional overrides (additive)
        // Supported values: info|warn|fail OR 0|1|2 (matching DriftSeverity)
        if (parsed.TryGetValue("--unmanaged-severity-qa", out var qaRaw))
        {
            if (!TryParseSeverity(qaRaw, out var s))
            {
                error = $"Invalid value for --unmanaged-severity-qa: '{qaRaw}'. Expected info|warn|fail or 0|1|2.";
                return false;
            }
            knobs = knobs with { QaUnmanaged = s };
        }

        if (parsed.TryGetValue("--unmanaged-severity-uat", out var uatRaw))
        {
            if (!TryParseSeverity(uatRaw, out var s))
            {
                error = $"Invalid value for --unmanaged-severity-uat: '{uatRaw}'. Expected info|warn|fail or 0|1|2.";
                return false;
            }
            knobs = knobs with { UatUnmanaged = s };
        }

        if (parsed.TryGetValue("--unmanaged-severity-live", out var liveRaw))
        {
            if (!TryParseSeverity(liveRaw, out var s))
            {
                error = $"Invalid value for --unmanaged-severity-live: '{liveRaw}'. Expected info|warn|fail or 0|1|2.";
                return false;
            }
            knobs = knobs with { LiveUnmanaged = s };
        }

        if (parsed.TryGetValue("--unmanaged-severity-not-managed-yet", out var nmRaw))
        {
            if (!TryParseSeverity(nmRaw, out var s))
            {
                error = $"Invalid value for --unmanaged-severity-not-managed-yet: '{nmRaw}'. Expected info|warn|fail or 0|1|2.";
                return false;
            }
            knobs = knobs with { NotManagedYetUnmanaged = s };
        }

        return true;
    }

    private static bool TryParseSeverity(string raw, out DriftSeverity severity)
    {
        severity = DriftSeverity.Info;

        if (string.IsNullOrWhiteSpace(raw))
            return false;

        raw = raw.Trim();

        // numeric
        if (int.TryParse(raw, out var n) && n >= 0 && n <= 2)
        {
            severity = (DriftSeverity)n;
            return true;
        }

        if (raw.Equals("info", StringComparison.OrdinalIgnoreCase))
        {
            severity = DriftSeverity.Info;
            return true;
        }

        if (raw.Equals("warn", StringComparison.OrdinalIgnoreCase) || raw.Equals("warning", StringComparison.OrdinalIgnoreCase))
        {
            severity = DriftSeverity.Warn;
            return true;
        }

        if (raw.Equals("fail", StringComparison.OrdinalIgnoreCase) || raw.Equals("error", StringComparison.OrdinalIgnoreCase))
        {
            severity = DriftSeverity.Fail;
            return true;
        }

        return false;
    }
}
